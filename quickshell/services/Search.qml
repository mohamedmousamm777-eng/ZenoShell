pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "../launcher/search.js" as S

// Brain of the launcher: turns the text into one unified list of results.
// Nothing runs while the launcher is closed.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string script: Quickshell.shellPath("scripts/launcher.sh")

    property string query: ""
    readonly property var parsed: S.parse(query)

    // Asynchronous results (valid only for the text they were made for)
    property string fileFor: ""
    property var files: []
    property var windows: []
    property string confirmId: ""     // dangerous action waiting for a second Enter

    function setQuery(q) {
        confirmId = ""
        query = q
        const p = S.parse(q)
        if (p.mode === "files") fileTimer.restart()
        else { fileTimer.stop(); if (files.length) { files = []; fileFor = "" } }
        if (p.mode === "windows" && !winProc.running) winProc.running = true
        if (p.mode === "clip") { ClipHist.refresh() }
        if (p.mode !== "windows" && windows.length) windows = []
    }

    // Text shown when the list is empty
    function hint(q, sector) {
        const p = S.parse(q)
        if (p.mode === "files") return p.arg === "" ? "Type a file or folder name" : "No files found"
        if (p.mode === "windows") return "No open windows found"
        if (p.mode === "clip") return ClipHist.available ? "Clipboard is empty" : "Needs cliphist and wl-clipboard"
        if (p.mode === "cmd" || p.mode === "bg") return "Type a command"
        if (p.mode === "web") return "Type what to search for"
        if (q !== "") return "No results"
        if (sector === "Favorites") return "No favorites yet: press Ctrl+F or right-click an app"
        if (sector === "Recent") return "No recent apps: open one from the launcher"
        return "No apps found"
    }

    function item(kind, id, name, sub, glyph, extra) {
        const o = { kind: kind, id: id, name: name, sub: sub, glyph: glyph }
        if (extra) for (const k in extra) o[k] = extra[k]
        return o
    }

    function compute(q, sector) {
        if (q.trim() === "") return Apps.filter("", sector)

        const p = S.parse(q)
        const out = []

        if (p.mode === "cmd")
            return p.arg === "" ? [] : [item("cmd", "cmd", p.arg, "Run in a terminal", ">", { text: p.arg })]
        if (p.mode === "bg")
            return p.arg === "" ? [] : [item("bg", "bg", p.arg, "Run in the background", "!", { text: p.arg })]

        if (p.mode === "files") {
            if (fileFor === p.arg) {
                for (let i = 0; i < files.length; i++) {
                    const f = files[i]
                    const base = f.replace(/\/+$/, "").split("/").pop()
                    const dir = S.shortPath(f.slice(0, f.length - base.length - (f.endsWith("/") ? 1 : 0)), home)
                    out.push(item("file", f, base, dir, f.endsWith("/") ? "D" : "F", { path: f }))
                }
            }
            return out
        }

        if (p.mode === "windows") {
            const a = p.arg.toLowerCase()
            for (let i = 0; i < windows.length; i++) {
                const w = windows[i]
                if (a !== "" && (w.title + " " + w.cls).toLowerCase().indexOf(a) < 0) continue
                out.push(item("window", w.id, w.title || w.cls, w.cls, "W", { wid: w.id }))
            }
            return out
        }

        if (p.mode === "clip") {
            const a = p.arg.toLowerCase()
            const it = ClipHist.items
            for (let i = 0; i < it.length; i++) {
                if (a !== "" && it[i].preview.toLowerCase().indexOf(a) < 0) continue
                out.push(item("clip", it[i].id, it[i].isImage ? "Image " + it[i].w + "×" + it[i].h : it[i].preview,
                              "Paste", "C", { cid: it[i].id }))
                if (out.length >= 40) break
            }
            return out
        }

        if (p.mode === "emoji") {
            const em = S.matchEmoji(p.arg)
            for (let i = 0; i < em.length; i++)
                out.push(item("emoji", em[i].ch, em[i].words.split(" ")[0], "Copy", em[i].ch, { text: em[i].ch, big: true }))
            return out
        }

        if (p.mode === "web") {
            if (p.arg === "") return []
            return [item("web", "web", p.arg, "Search on " + p.engine.name, "G", { url: S.engineUrl(p.engine, p.arg) })]
        }

        // ----- Normal: calculator / units / address, then apps, then system, then web
        const text = q.trim()
        const conv = S.convert(text)
        if (conv) {
            out.push(item("calc", "calc", conv.value + " " + conv.unit, "Press Enter to copy", "=", { text: conv.value }))
        } else {
            const v = S.evalExpr(text)
            if (v !== null) out.push(item("calc", "calc", S.fmt(v), text + " · Enter to copy", "=", { text: S.fmt(v) }))
        }

        if (S.looksLikeUrl(text))
            out.push(item("url", "url", text, "Open in the browser", "@", { url: S.toUrl(text) }))

        const apps = Apps.filter(q, sector)
        for (let i = 0; i < apps.length; i++) out.push(apps[i])

        const sys = S.matchSystem(text)
        for (let i = 0; i < sys.length; i++) {
            const waiting = confirmId === sys[i].id
            out.push(item("system", sys[i].id, sys[i].name,
                          waiting ? "Press Enter again to confirm" : (sys[i].danger ? "System · asks to confirm" : "System"),
                          sys[i].glyph, { action: sys[i].action, danger: sys[i].danger }))
        }

        const eng = S.engines[0]
        out.push(item("web", "web", text, "Search on " + eng.name, "G", { url: S.engineUrl(eng, text) }))
        return out
    }

    // Executes the choice. Returns true if the launcher can close.
    function run(it) {
        const k = it.kind
        if (k === undefined) { Apps.launch(it.entry); return true }

        if (k === "cmd") {
            Quickshell.execDetached(["kitty", "--hold", "sh", "-c", it.text])
        } else if (k === "bg") {
            Quickshell.execDetached(["sh", "-c", it.text])
        } else if (k === "file") {
            Quickshell.execDetached(["xdg-open", it.path])
        } else if (k === "web" || k === "url") {
            Quickshell.execDetached(["xdg-open", it.url])
        } else if (k === "window") {
            Quickshell.execDetached(["sh", script, "focus", it.wid])
        } else if (k === "clip") {
            ClipHist.paste(it.cid)
        } else if (k === "emoji" || k === "calc") {
            Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", it.text])
        } else if (k === "system") {
            if (it.danger && confirmId !== it.id) { confirmId = it.id; return false }
            Power.run(it.action)
        }
        return true
    }

    Timer {
        id: fileTimer
        interval: 150
        onTriggered: root.startFiles()
    }

    property string fileWanted: ""
    property string fileRunning: ""

    function startFiles() {
        const a = S.parse(query).arg
        fileWanted = a
        if (a === "") { files = []; fileFor = ""; return }
        if (fileProc.running) { fileProc.running = false; return }   // onExited starts the new one
        fileRunning = a
        fileProc.command = ["sh", script, "files", a]
        fileProc.running = true
    }

    Process {
        id: fileProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.fileRunning !== root.fileWanted) return
                root.files = text.split("\n").filter(l => l !== "")
                root.fileFor = root.fileRunning
            }
        }
        onExited: if (root.fileRunning !== root.fileWanted && S.parse(root.query).mode === "files") root.startFiles()
    }

    Process {
        id: winProc
        command: ["sh", root.script, "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const f = lines[i].split("\t")
                    if (f.length < 2 || f[0] === "") continue
                    out.push({ id: f[0], cls: f[1], title: f.slice(2).join(" ") })
                }
                root.windows = out
            }
        }
    }
}
