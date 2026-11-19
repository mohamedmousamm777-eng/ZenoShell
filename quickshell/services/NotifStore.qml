pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Saved history of the notifications (Notification Center).
//  - Every notification that arrives is appended as one JSON line to ~/.local/state/quickshell/notifs.jsonl
//    (writes go through one queue, one process at a time, so lines never mix).
//  - The list is read from the file ONLY while the panel shows the History tab (acquire / release):
//    with the panel closed nothing is kept in memory.
//  - Old lines are cut away once after the start: older than 30 days, or more than 500 lines.
//  - The "Save history" switch lives in ~/.local/state/quickshell/notif-rules.json (the same file will
//    hold the rules of the next stage).
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string histPath: stateDir + "/notifs.jsonl"
    readonly property string cfgPath: stateDir + "/notif-rules.json"

    readonly property int maxEntries: 500
    readonly property real maxAgeMs: 30 * 86400000

    // ---------- Settings ----------
    property bool saveHistory: true
    property var cfgData: ({})                 // whole content of notif-rules.json (other keys are kept as they are)

    function setSaveHistory(on) {
        saveHistory = on
        const d = Object.assign({}, cfgData)
        d.saveHistory = on
        cfgData = d
        try { cfg.setText(JSON.stringify(cfgData, null, 2)) } catch (e) {}
    }

    // ---------- Data ----------
    property var entries: []                   // newest first; filled only while somebody uses it
    property int total: -1                     // lines in the file (-1 = not counted yet)
    property int users: 0
    property bool loading: false

    property int seq: 0

    // Entry: { id, t (ms), app, summary, body, urg (0 low, 1 normal, 2 critical) }
    function makeEntry(app, summary, body, urg) {
        const t = Date.now()
        return {
            id: t.toString(36) + (seq++).toString(36),
            t: t,
            app: String(app || "?").slice(0, 80),
            summary: String(summary || "").slice(0, 300),
            body: String(body || "").slice(0, 2000),
            urg: urg === 2 ? 2 : (urg === 0 ? 0 : 1)
        }
    }

    // Called by NotifCenter for every notification that arrives
    function add(app, summary, body, urg) {
        if (!saveHistory) return
        const e = makeEntry(app, summary, body, urg)
        if (total >= 0) total++
        if (users > 0) {
            const arr = [e].concat(entries)
            entries = arr.length > maxEntries ? arr.slice(0, maxEntries) : arr
        }
        enqueue(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" >> "$1"', "sh", histPath, JSON.stringify(e)])
    }

    function clear() {
        entries = []
        total = 0
        enqueue(["rm", "-f", histPath])
    }

    // ---------- Use by the panel ----------
    function acquire() {
        users++
        if (users === 1) load()
    }
    function release() {
        if (users <= 0) return
        users--
        if (users === 0) entries = []
    }

    function refreshCount() { countProc.running = true }

    // ---------- Write queue ----------
    property var queue: []
    property bool loadWanted: false

    function enqueue(cmd) { queue.push(cmd); pump() }

    function pump() {
        if (writer.running) return
        if (queue.length > 0) {
            writer.command = queue.shift()
            writer.running = true
        } else if (loadWanted) {
            loadWanted = false
            reader.running = true
        }
    }

    // Reads the last lines of the file. Waits for the writes still in the queue, so nothing is missed.
    function load() {
        loading = true
        loadWanted = true
        pump()
    }

    function prune() {
        // keeps only the lines younger than 30 days, and then the last 500
        const cut = Date.now() - maxAgeMs
        enqueue(["sh", "-c",
            'f="$1"; [ -f "$f" ] || exit 0; ' +
            'awk -v cut="$2" \'match($0, /"t":[0-9]+/) { if (substr($0, RSTART + 4, RLENGTH - 4) + 0 >= cut + 0) print }\' "$f" ' +
            '| tail -n "$3" > "$f.tmp" && mv "$f.tmp" "$f"',
            "sh", histPath, String(cut), String(maxEntries)])
    }

    function parseLines(text) {
        const out = []
        const lines = text.split("\n")
        for (let i = lines.length - 1; i >= 0; i--) {            // newest first
            const l = lines[i]
            if (l === "") continue
            try {
                const o = JSON.parse(l)
                if (typeof o.t !== "number") continue
                out.push({
                    id: String(o.id || o.t),
                    t: o.t,
                    app: String(o.app || "?"),
                    summary: String(o.summary || ""),
                    body: String(o.body || ""),
                    urg: o.urg === 2 ? 2 : (o.urg === 0 ? 0 : 1)
                })
            } catch (e) {}
        }
        return out
    }

    Process {
        id: writer
        onExited: root.pump()
    }

    Process {
        id: reader
        command: ["sh", "-c", '[ -f "$1" ] && tail -n "$2" "$1" || true', "sh", root.histPath, String(root.maxEntries)]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                if (root.users <= 0) return                   // the panel closed meanwhile
                const loaded = root.parseLines(text)
                // entries that arrived while reading and are not in the result yet
                const seen = {}
                for (let i = 0; i < loaded.length; i++) seen[loaded[i].id] = true
                const late = []
                for (let i = 0; i < root.entries.length; i++)
                    if (!seen[root.entries[i].id]) late.push(root.entries[i])
                root.entries = late.concat(loaded).slice(0, root.maxEntries)
                root.total = Math.max(root.total, root.entries.length)
            }
        }
        onExited: root.pump()
    }

    Process {
        id: countProc
        command: ["sh", "-c", '[ -f "$1" ] && wc -l < "$1" || echo 0', "sh", root.histPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim())
                if (!isNaN(n)) root.total = n
            }
        }
    }

    // ---------- Saved settings ----------
    FileView {
        id: cfg
        path: root.cfgPath
        blockLoading: true
        printErrors: false
    }

    Timer {
        id: pruneTimer
        interval: 30000
        onTriggered: root.prune()
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.stateDir])
        try {
            const d = JSON.parse(cfg.text())
            if (d && typeof d === "object") {
                cfgData = d
                if (typeof d.saveHistory === "boolean") saveHistory = d.saveHistory
            }
        } catch (e) {}
        pruneTimer.start()
    }
}
