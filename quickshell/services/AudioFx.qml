pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.services

// Equalizer of the Audio Center.
// When it is on, a PipeWire filter ("ZenoShell EQ", made by scripts/audiofx.sh) becomes the default output
// and plays on the real one. When it is off the process is stopped and the real output is the default again:
// zero cost. Saved in ~/.local/state/quickshell/audiofx.json.
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string confPath: stateDir + "/audiofx.conf"
    readonly property string script: Quickshell.shellPath("scripts/audiofx.sh")

    readonly property string fxSink: "zeno_eq_sink"
    readonly property string fxOut: "zeno_eq_out"
    function isFx(node) { return node && (node.name === fxSink || node.name === fxOut) }

    // ---------- Settings ----------
    property bool enabled: false                // the user asked for the equalizer
    property bool headroom: true                // lowers the whole signal as much as the highest boost (no clipping)
    property string preset: "Flat"
    property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]          // dB, -12..+12
    property var userPresets: []                // [{ name, gains }]
    property real balance: 0                    // -1 (left) .. +1 (right)

    readonly property var freqLabels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property real range: 12

    readonly property var builtIn: [
        { name: "Flat",    gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
        { name: "Bass",    gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0] },
        { name: "Treble",  gains: [0, 0, 0, 0, 0, 1, 3, 4, 5, 6] },
        { name: "Vocal",   gains: [-3, -2, 0, 2, 4, 4, 3, 1, 0, -1] },
        { name: "Pop",     gains: [-1, 2, 4, 5, 3, 0, -1, -1, -1, -1] },
        { name: "Rock",    gains: [5, 4, 3, 1, -1, -2, 0, 2, 3, 4] },
        { name: "Jazz",    gains: [4, 3, 1, 2, -2, -2, 0, 1, 3, 4] },
        { name: "Classic", gains: [0, 0, 0, 0, 0, 0, -3, -3, -3, -5] }
    ]
    readonly property var allPresets: builtIn.concat(userPresets)

    // dB taken off the whole signal when the bands boost
    readonly property real preamp: headroom ? -Math.max(0, Math.max.apply(null, gains)) : 0

    // Simple Bass / Treble: the average of the first / last three bands
    readonly property real bass: (gains[0] + gains[1] + gains[2]) / 3
    readonly property real treble: (gains[7] + gains[8] + gains[9]) / 3

    // ---------- State ----------
    property string target: ""                  // name of the real output the filter plays on
    property string previousDefault: ""
    property bool starting: false
    readonly property bool active: eq.running && fxReady       // the filter is up and is the default output
    property bool fxReady: false
    property string error: ""

    function clamp(v) { return Math.max(-range, Math.min(range, Math.round(v * 2) / 2)) }

    // ---------- Changes made by the user ----------
    function setEnabled(on) {
        if (on === enabled) return
        enabled = on
        save()
        if (on) start(); else stop()
    }
    function toggle() { setEnabled(!enabled) }

    function setBand(i, v) {
        if (i < 0 || i > 9) return
        const g = gains.slice()
        g[i] = clamp(v)
        gains = g
        preset = ""
        changed()
    }

    function setBass(v) {
        const g = gains.slice()
        g[0] = clamp(v); g[1] = clamp(v * 0.8); g[2] = clamp(v * 0.5)
        gains = g; preset = ""; changed()
    }
    function setTreble(v) {
        const g = gains.slice()
        g[9] = clamp(v); g[8] = clamp(v * 0.8); g[7] = clamp(v * 0.5)
        gains = g; preset = ""; changed()
    }

    function setPreset(name) {
        for (let i = 0; i < allPresets.length; i++) {
            if (allPresets[i].name === name) {
                gains = allPresets[i].gains.map(clamp)
                preset = name
                changed()
                return true
            }
        }
        return false
    }

    function nextPreset(d) {
        const list = allPresets
        let i = -1
        for (let k = 0; k < list.length; k++) if (list[k].name === preset) i = k
        i = (i + d + list.length) % list.length
        setPreset(list[i].name)
        if (!enabled) setEnabled(true)
        return list[i].name
    }

    function reset() { setPreset("Flat") }

    function setHeadroom(on) { headroom = on; changed() }

    function setBalance(v) {
        balance = Math.max(-1, Math.min(1, Math.round(v * 20) / 20))
        changed()
    }

    // Picks a preset and turns the equalizer on (used by the buttons of the panels)
    function choose(name) {
        setPreset(name)
        if (!enabled) setEnabled(true)
    }

    // Saves the current curve as "Mine 1", "Mine 2"...
    function saveCurrent() {
        let n = 1
        while (userPresets.some(p => p.name === "Mine " + n)) n++
        return saveUserPreset("Mine " + n)
    }

    function isMine(name) { return userPresets.some(p => p.name === name) }

    function saveUserPreset(name) {
        name = String(name).trim().slice(0, 24)
        if (name === "") return false
        for (let i = 0; i < builtIn.length; i++) if (builtIn[i].name.toLowerCase() === name.toLowerCase()) return false
        const list = userPresets.filter(p => p.name !== name)
        list.push({ name: name, gains: gains.slice() })
        userPresets = list
        preset = name
        save()
        return true
    }

    function deleteUserPreset(name) {
        userPresets = userPresets.filter(p => p.name !== name)
        if (preset === name) preset = ""
        save()
    }

    // ---------- Engine ----------
    function args() {
        return [String(preamp), String(balance)].concat(gains.map(String))
    }

    // One change: lowers the volume of nothing until the filter exists; applied after 60 ms, saved after half a second
    function changed() {
        applyTimer.restart()
        saveTimer.restart()
    }

    property bool applyAgain: false

    Timer {
        id: applyTimer
        interval: 50
        onTriggered: {
            if (!root.active) return
            if (apply.running) root.applyAgain = true      // a call is still going: one more right after it, with the latest values
            else apply.running = true
        }
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: root.save()
    }

    // Live gains: if pw-cli cannot do it, the filter is rebuilt
    Process {
        id: apply
        command: ["sh", root.script, "apply"].concat(root.args())
        onExited: code => {
            if (code !== 0 && root.enabled) { root.applyAgain = false; root.restart() }
            else if (root.applyAgain) { root.applyAgain = false; apply.running = true }
        }
    }

    function realSinkNode() {
        const v = Pipewire.nodes.values
        for (let i = 0; i < v.length; i++)
            if (v[i].isSink && !v[i].isStream && !isFx(v[i]) && v[i].name === target) return v[i]
        return null
    }

    function start() {
        if (eq.running || gen.running) return
        error = ""
        const cur = Pipewire.defaultAudioSink
        if (cur && !isFx(cur)) target = cur.name
        if (target === "") { error = "No audio output found"; enabled = false; save(); return }
        previousDefault = target
        starting = true
        gen.running = true
    }

    function restart() {
        if (!enabled) return
        fxReady = false
        eq.running = false
        restartTimer.restart()
    }

    Timer {
        id: restartTimer
        interval: 400
        onTriggered: { gen.running = false; root.start() }
    }

    function stop() {
        starting = false
        fxReady = false
        pollTimer.stop()
        eq.running = false
        // the real output comes back as the default
        const real = realSinkNode()
        if (real) Pipewire.preferredDefaultAudioSink = real
    }

    // The user picks another output while the filter is on: the filter plays on that one
    function setTarget(node) {
        if (!node) return
        target = node.name
        if (enabled) restart()
        else Pipewire.preferredDefaultAudioSink = node
    }

    Process {
        id: gen
        command: ["sh", root.script, "gen", root.confPath, root.target].concat(root.args())
        onExited: code => {
            if (code === 0 && root.enabled) eq.running = true
            else { root.error = "Could not write the equalizer configuration"; root.enabled = false; root.starting = false; root.save() }
        }
    }

    Process {
        id: eq
        command: ["pipewire", "-c", root.confPath]
        onRunningChanged: {
            if (running) { pollTimer.count = 0; pollTimer.restart() }
            else if (root.enabled && !restartTimer.running && !root.starting) {
                // it stopped by itself (pipewire missing or crashed): back to the normal output
                root.fxReady = false
                root.error = "The equalizer stopped"
                root.enabled = false
                const real = root.realSinkNode()
                if (real) Pipewire.preferredDefaultAudioSink = real
                root.save()
            }
        }
    }

    // Waits for the virtual output to appear, then makes it the default
    Timer {
        id: pollTimer
        property int count: 0
        interval: 250
        repeat: true
        onTriggered: {
            count++
            const v = Pipewire.nodes.values
            for (let i = 0; i < v.length; i++) {
                if (v[i].name === root.fxSink && v[i].isSink) {
                    Pipewire.preferredDefaultAudioSink = v[i]
                    root.fxReady = true
                    root.starting = false
                    pollTimer.stop()
                    return
                }
            }
            if (count >= 24) {
                root.error = "The equalizer did not start (is pipewire's filter-chain available?)"
                root.starting = false
                root.enabled = false
                eq.running = false
                root.save()
                pollTimer.stop()
            }
        }
    }

    // ---------- Saving ----------
    FileView {
        id: store
        path: root.stateDir + "/audiofx.json"
        blockLoading: true
        printErrors: false
    }

    function save() {
        try {
            store.setText(JSON.stringify({
                enabled: enabled, headroom: headroom, preset: preset,
                gains: gains, userPresets: userPresets, target: target, balance: balance
            }))
        } catch (e) { console.log("audiofx: save:", e) }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        try {
            const d = JSON.parse(store.text())
            if (Array.isArray(d.gains) && d.gains.length === 10) gains = d.gains.map(x => clamp(Number(x) || 0))
            if (typeof d.preset === "string") preset = d.preset
            if (typeof d.headroom === "boolean") headroom = d.headroom
            if (Array.isArray(d.userPresets))
                userPresets = d.userPresets.filter(p => p && typeof p.name === "string" && Array.isArray(p.gains) && p.gains.length === 10)
                                           .map(p => ({ name: p.name, gains: p.gains.map(x => clamp(Number(x) || 0)) }))
            if (typeof d.target === "string") target = d.target
            if (typeof d.balance === "number") balance = Math.max(-1, Math.min(1, d.balance))
            if (d.enabled === true) { enabled = true; bootTimer.start() }
        } catch (e) {}
    }

    // Starts again after a login, when PipeWire has had the time to show its outputs
    Timer {
        id: bootTimer
        interval: 2500
        onTriggered: { if (root.enabled) root.start() }
    }
}
