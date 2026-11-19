pragma Singleton

import QtQuick
import Quickshell
import qs.services
import Quickshell.Io

Singleton {
    id: root

    property bool pinned: false       // pinned (qs ipc call system toggle)
    property bool peek: false         // temporary appearance (qs ipc call system show)
    property bool edgeOpen: false     // mouse on the edge or the panel
    property bool edgeHot: false
    property string screen: ""        // monitor to show it on

    readonly property bool shown: pinned || peek || edgeOpen
    property int users: 0              // other views (dashboard) that need live readings

    // ---------- System Monitor (the pill grows into it) ----------
    property bool monitorOpen: false
    property string monitorScreen: ""
    property string monitorView: "cpu"      // cpu | ram | gpu | temp | proc | net
    readonly property bool polling: shown || users > 0 || monitorOpen

    function openMonitor(screenName, view) {
        monitorScreen = (screenName && screenName !== "") ? screenName : Compositor.focusedMonitor
        if (view) monitorView = view
        monitorOpen = true
    }
    function closeMonitor() { monitorOpen = false }
    function toggleMonitor() { if (monitorOpen) closeMonitor(); else openMonitor("", "") }
    function setView(v) { if (["cpu", "ram", "gpu", "temp", "proc", "net"].indexOf(v) >= 0) monitorView = v }

    property real cpu: 0              // 0..1
    property real ramUsed: 0          // byte
    property real ramTotal: 1
    property real diskUsed: 0
    property real diskTotal: 1
    property real netDown: 0          // byte/s
    property real netUp: 0

    // ---------- Only read while the monitor is open ----------
    property real memFree: 0           // byte
    property real memBuffers: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapFree: 0
    property real freqMhz: 0
    property var load: [0, 0, 0]
    property int uptime: 0             // seconds
    property int tasks: 0              // processes and threads in the system
    property string cpuModel: ""
    property int cores: 0
    property int threads: 1
    property string gpuVendor: ""
    property bool gpuPresent: false
    property var gpus: []              // every graphics chip found: [{ n, maker, integrated, est, busy 0..1, vramUsed, vramTotal, clock, power, temp }]
    property real gpuBusy: 0           // 0..1  (the busiest chip)
    property real gpuVramUsed: -1      // byte, -1 = unknown
    property real gpuVramTotal: -1
    property real gpuClock: -1         // MHz
    property real gpuPower: -1         // W
    property var temps: []             // [{ name, c }]
    property var fans: []              // [{ name, rpm }]
    property var ifaces: []            // [{ name, down, up }] byte/s
    property real totalRx: 0           // byte since boot
    property real totalTx: 0
    property var procs: []             // [{ pid, cpu, mem, name }]  cpu per logical core, as top shows it
    readonly property real maxTemp: {
        let m = 0
        for (let i = 0; i < temps.length; i++) if (temps[i].c > m) m = temps[i].c
        return m
    }

    // Last 2 minutes (60 readings, 2 s apart): in place, the views follow histRev
    property var hist: ({ cpu: [], ram: [], gpu: [], temp: [], down: [], up: [] })
    property int histRev: 0
    readonly property int histLen: 60

    // ---------- Temperature warning (off by default) ----------
    property bool alertOn: false
    property int alertTemp: 85
    property double lastAlert: 0

    function setAlert(on) { alertOn = on; saveCfg() }

    readonly property real ram: ramTotal > 0 ? ramUsed / ramTotal : 0
    readonly property real disk: diskTotal > 0 ? diskUsed / diskTotal : 0

    property var prevCpu: null
    property var prevNet: null
    property double prevTime: 0

    function fmtRate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s"
        if (b >= 1024) return Math.round(b / 1024) + " KB/s"
        return Math.round(b) + " B/s"
    }

    // Called from the hot area on the edge (and from the panel itself)
    function setEdge(hovered, screenName) {
        if (hovered) {
            screen = screenName
            edgeHot = true
            edgeOpen = true
            closeTimer.stop()
        } else {
            edgeHot = false
            closeTimer.restart()
        }
    }

    function show(ms) {
        screen = Compositor.focusedMonitor
        peek = true
        peekTimer.interval = ms
        peekTimer.restart()
    }

    function togglePin() {
        if (pinned) {
            pinned = false
            peek = false
        } else {
            screen = Compositor.focusedMonitor
            pinned = true
        }
    }

    function hide() {
        pinned = false
        peek = false
        edgeOpen = false
        peekTimer.stop()
    }

    // When it reappears, readings restart from zero (no fake spikes)
    onPollingChanged: {
        prevCpu = null
        prevNet = null
        prevIface = ({})
    }

    // Opened: the one-time data and the first process list. Closed: the history and the lists are freed.
    onMonitorOpenChanged: {
        if (monitorOpen) {
            if (cpuModel === "") stat.running = true
            if (procView) procTimer.restart()
        } else {
            hist = ({ cpu: [], ram: [], gpu: [], temp: [], down: [], up: [] })
            procs = []
            temps = []; fans = []; ifaces = []
            procTimer.stop()
        }
    }

    readonly property bool procView: monitorOpen && ["cpu", "ram", "proc"].indexOf(monitorView) >= 0
    onProcViewChanged: if (procView) procTimer.restart(); else procTimer.stop()

    property var prevIface: ({})

    function pushHist(k, v) {
        const a = hist[k]
        a.push(v)
        if (a.length > histLen) a.shift()
    }

    // Closes a process: SIGTERM (asks it to stop) or SIGKILL (forces it). Numbers only, nothing else gets through.
    function signal(pid, sig) {
        pid = Number(pid)
        if (!Number.isInteger(pid) || pid < 2) return
        if (sig !== "TERM" && sig !== "KILL") return
        Quickshell.execDetached(["kill", "-" + sig, String(pid)])
        procs = procs.filter(p => p.pid !== pid)
    }

    Timer {
        id: closeTimer
        interval: 260
        onTriggered: if (!root.edgeHot) root.edgeOpen = false
    }

    Timer {
        id: peekTimer
        onTriggered: root.peek = false
    }

    function parse(text) {
        const now = Date.now()
        const lines = text.split("\n")
        const newTemps = [], newFans = [], newIfaces = [], newGpus = []
        const ifs = {}

        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].trim().split(/\s+/)
            if (f.length < 2) continue

            if (f[0] === "cpu") {
                const n = f.slice(1).map(Number)
                const total = n.slice(0, 8).reduce((a, b) => a + b, 0)
                const idle = n[3] + n[4]
                if (prevCpu) {
                    const dt = total - prevCpu.total
                    const di = idle - prevCpu.idle
                    if (dt > 0) cpu = Math.max(0, Math.min(1, 1 - di / dt))
                }
                prevCpu = { total: total, idle: idle }
            } else if (f[0] === "memtotal") {
                ramTotal = parseFloat(f[1]) * 1024
            } else if (f[0] === "memavail") {
                ramUsed = Math.max(0, ramTotal - parseFloat(f[1]) * 1024)
            } else if (f[0] === "net") {
                const rx = parseFloat(f[1])
                const tx = parseFloat(f[2])
                if (prevNet && now > prevTime) {
                    const s = (now - prevTime) / 1000
                    netDown = Math.max(0, (rx - prevNet.rx) / s)
                    netUp = Math.max(0, (tx - prevNet.tx) / s)
                }
                prevNet = { rx: rx, tx: tx }
                prevTime = now
            } else if (f[0] === "disk") {
                diskTotal = parseFloat(f[1])
                diskUsed = parseFloat(f[2])
            } else if (f[0] === "memfree") { memFree = parseFloat(f[1]) * 1024
            } else if (f[0] === "buffers") { memBuffers = parseFloat(f[1]) * 1024
            } else if (f[0] === "cached") { memCached = parseFloat(f[1]) * 1024
            } else if (f[0] === "swaptotal") { swapTotal = parseFloat(f[1]) * 1024
            } else if (f[0] === "swapfree") { swapFree = parseFloat(f[1]) * 1024
            } else if (f[0] === "freq") { freqMhz = parseFloat(f[1])
            } else if (f[0] === "uptime") { uptime = parseInt(f[1])
            } else if (f[0] === "load" && f.length >= 4) { load = [f[1], f[2], f[3]].map(Number)
            } else if (f[0] === "tasks") { tasks = parseInt(f[1]) || 0
            } else if (f[0] === "iface" && f.length >= 4) {
                ifs[f[1]] = { rx: parseFloat(f[2]), tx: parseFloat(f[3]) }
            } else if (f[0] === "temp" && f.length >= 3) {
                const c = parseFloat(f[1]) / 1000
                if (c > -50 && c < 150) newTemps.push({ name: f[2].replace(/_/g, " "), c: c })
            } else if (f[0] === "fan" && f.length >= 3) {
                const rpm = parseFloat(f[1])
                if (rpm > 0) newFans.push({ name: f[2].replace(/_/g, " "), rpm: rpm })
            } else if (f[0] === "gpu" && f.length >= 11) {
                const b = parseFloat(f[5])
                newGpus.push({
                    n: parseInt(f[1]), maker: f[2], integrated: f[3] === "integrated", est: f[4] === "1",
                    busy: b >= 0 ? Math.min(1, b / 100) : 0, busyKnown: b >= 0,
                    vramUsed: parseFloat(f[6]), vramTotal: parseFloat(f[7]),
                    clock: parseFloat(f[8]), power: parseFloat(f[9]), temp: parseFloat(f[10])
                })
            }
        }

        if (!monitorOpen) return

        // Interfaces: speeds from the difference with the last reading
        for (const n in ifs) {
            const pv = prevIface[n]
            let d = 0, u = 0
            if (pv && now > prevTime0) {
                const sec = (now - prevTime0) / 1000
                d = Math.max(0, (ifs[n].rx - pv.rx) / sec)
                u = Math.max(0, (ifs[n].tx - pv.tx) / sec)
            }
            newIfaces.push({ name: n, down: d, up: u, rx: ifs[n].rx, tx: ifs[n].tx })
        }
        prevIface = ifs
        prevTime0 = now
        ifaces = newIfaces
        let rx = 0, tx = 0
        for (let i = 0; i < newIfaces.length; i++) { rx += newIfaces[i].rx; tx += newIfaces[i].tx }
        totalRx = rx; totalTx = tx
        temps = newTemps
        fans = newFans
        // Graphics: all the chips (the one inside the CPU too); the headline numbers are those of the busiest one
        gpus = newGpus
        gpuPresent = newGpus.length > 0
        if (gpuPresent) {
            let pi = 0
            for (let i = 1; i < newGpus.length; i++) if (newGpus[i].busy > newGpus[pi].busy) pi = i
            const g = newGpus[pi]
            gpuVendor = g.maker + (g.integrated ? " · integrated" : "")
            gpuBusy = g.busy
            gpuVramUsed = g.vramUsed; gpuVramTotal = g.vramTotal
            gpuClock = g.clock; gpuPower = g.power
        }

        pushHist("cpu", cpu * 100)
        pushHist("ram", ram * 100)
        pushHist("gpu", gpuBusy * 100)
        pushHist("temp", maxTemp)
        pushHist("down", netDown / 1048576)
        pushHist("up", netUp / 1048576)
        histRev++

        if (alertOn && maxTemp >= alertTemp && now - lastAlert > 120000) {
            lastAlert = now
            Toast.push({ kind: "battery", app: "System Monitor", summary: "Temperature " + Math.round(maxTemp) + " °C",
                         body: "Above the " + alertTemp + " °C you set", tone: "danger", duration: 8000 })
        }
    }

    property double prevTime0: 0

    function parseStatic(text) {
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const k = lines[i].indexOf(" ")
            if (k < 0) continue
            const key = lines[i].slice(0, k), val = lines[i].slice(k + 1).trim()
            if (key === "model") cpuModel = val
            else if (key === "cores") cores = parseInt(val) || 0
            else if (key === "threads") threads = Math.max(1, parseInt(val) || 1)
            else if (key === "gpuvendor") gpuVendor = val
        }
    }

    function parseProcs(text) {
        const out = []
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].split("\t")
            if (f.length < 4) continue
            const pid = parseInt(f[0])
            if (!pid) continue
            out.push({ pid: pid, cpu: parseFloat(f[1]) || 0, mem: parseFloat(f[2]) || 0, name: f[3] })
        }
        procs = out
    }

    Process {
        id: proc
        command: root.monitorOpen ? ["sh", Quickshell.shellPath("scripts/sysstats.sh"), "full"]
                                  : ["sh", Quickshell.shellPath("scripts/sysstats.sh")]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    // Things that never change (CPU model, cores): read once, the first time the monitor opens
    Process {
        id: stat
        command: ["sh", Quickshell.shellPath("scripts/sysstats.sh"), "static"]
        stdout: StdioCollector { onStreamFinished: root.parseStatic(text) }
    }

    // Busiest processes: only while a view that shows them is on screen
    Process {
        id: procRun
        command: ["sh", Quickshell.shellPath("scripts/procs.sh")]
        stdout: StdioCollector { onStreamFinished: root.parseProcs(text) }
    }

    Timer {
        id: procTimer
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!procRun.running) procRun.running = true
    }

    // Reads data only while the panel is visible (every 2 s with the monitor open, every second otherwise)
    Timer {
        interval: root.monitorOpen ? 2000 : 1000
        running: root.polling
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }

    // ---------- Saved: only the warning ----------
    readonly property string cfgPath: Quickshell.env("HOME") + "/.local/state/quickshell/sysmon.json"

    FileView {
        id: cfg
        path: root.cfgPath
        blockLoading: true
        printErrors: false
    }

    function saveCfg() {
        try { cfg.setText(JSON.stringify({ alertOn: alertOn, alertTemp: alertTemp })) } catch (e) {}
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/quickshell"])
        try {
            const d = JSON.parse(cfg.text())
            if (typeof d.alertOn === "boolean") alertOn = d.alertOn
            if (typeof d.alertTemp === "number") alertTemp = Math.max(50, Math.min(110, d.alertTemp))
        } catch (e) {}
    }
}
