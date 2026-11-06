pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

// Animated wallpaper (video or GIF): the state, and when to pause.
// The picture is drawn by wallpaper/LiveWallpaper.qml. apply-live.sh writes the playing file in
// ~/.cache/quickshell-live-current and sets the still frame as the normal wallpaper (awww + pywal).
// Smart pause (Settings.livePause): a window covering the monitor (fullscreen), lock screen, Game Mode,
// Eco Mode, screen off, and a PC under heavy load (CPU / RAM), so the animation never makes things worse.
// Turned off (Settings > Wallpaper, or `qs ipc call livewall off`): nothing is decoded, the still frame stays.
Singleton {
    id: root

    readonly property string statePath: Quickshell.env("HOME") + "/.cache/quickshell-live-current"

    property string path: ""                        // file being played ("" = none)
    readonly property bool isGif: /\.gif$/i.test(path)
    readonly property url url: path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/")

    property bool screenOff: false                  // set by settings/IdleWatcher.qml
    property var covered: []                        // monitors with a window covering them
    property bool busy: false                       // CPU / RAM under heavy load (with hysteresis)

    property bool videoMissing: false               // set by LiveWallpaper: Qt Multimedia is not installed
    property string playerError: ""                 // set by VideoLayer: the file cannot be played

    // The window exists (and the player runs) only when this is true
    readonly property bool wanted: Settings.liveEnabled && path !== ""
    // The pause rules are checked (and the system is watched) only then
    readonly property bool watching: wanted && Settings.livePause

    readonly property bool globalPause: Settings.livePause && (UiState.locked || GameMode.on || PowerSaver.on || screenOff || busy)

    function pausedOn(name) { return globalPause || (Settings.livePause && covered.indexOf(name) >= 0) }

    // Why it is paused, for the Settings page
    readonly property string pauseReason: {
        if (!Settings.livePause) return ""
        if (UiState.locked) return "lock screen"
        if (screenOff) return "screen off"
        if (GameMode.on) return "Game Mode"
        if (PowerSaver.on) return "Eco Mode"
        if (busy) return "the PC is busy"
        if (covered.length > 0) return "a window covers the screen"
        return ""
    }

    readonly property string statusText: {
        if (path === "") return "none: no animated wallpaper applied"
        if (!Settings.liveEnabled) return "off: " + path
        if (!isGif && videoMissing) return "cannot play: Qt Multimedia is not installed (package qt6-multimedia)"
        if (!isGif && playerError !== "") return "cannot play: " + playerError
        return (pauseReason !== "" ? "paused (" + pauseReason + "): " : "playing: ") + path
    }

    function clear() {
        Quickshell.execDetached(["rm", "-f", statePath])
        path = ""
    }

    onPathChanged: playerError = ""

    // ---- the applied file ----
    // The scripts call `qs ipc call livewall reload` after changing the file
    function reload() { stateFile.reload() }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        onLoaded: root.path = String(text()).trim()
        onLoadFailed: root.path = ""
    }

    // ---- a window covering a monitor ----
    property bool again: false

    function check() {
        if (!watching) return
        if (probe.running) again = true
        else probe.running = true
    }

    Process {
        id: probe
        command: ["sh", Quickshell.shellPath("scripts/covered.sh")]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(s => s !== "")
                if (list.join(",") !== root.covered.join(",")) root.covered = list
            }
        }

        onExited: if (root.again) { root.again = false; running = true }
    }

    Timer { id: debounce; interval: 150; onTriggered: root.check() }


    Connections {
        target: Compositor
        function onLayoutEvent() { if (root.watching) debounce.restart() }
    }

    readonly property var hyprEvents: ({
        fullscreen: true, workspace: true, workspacev2: true, focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true, movewindow: true, movewindowv2: true,
        monitoradded: true, monitorremoved: true
    })

    Connections {
        target: Compositor.isHyprland ? Hyprland : null
        function onRawEvent(ev) { if (root.watching && root.hyprEvents[ev.name]) debounce.restart() }
    }

    // Safety net, only while an animated wallpaper is on
    Timer {
        interval: 10000
        running: root.watching
        repeat: true
        onTriggered: root.check()
    }

    // ---- a PC under load ----
    // The CPU / RAM readings are only taken while the animation is watched (SysStats.users).
    property bool counting: false
    onWatchingChanged: {
        if (watching && !counting) { SysStats.users++; counting = true }
        else if (!watching && counting) { SysStats.users--; counting = false; busy = false }
        if (watching) check(); else covered = []
    }

    readonly property bool hot: SysStats.cpu > 0.85 || SysStats.ram > 0.90
    readonly property bool calm: SysStats.cpu < 0.70 && SysStats.ram < 0.80

    // It pauses only if the load lasts (4 s) and resumes only when calm and after at least 20 s:
    // otherwise pausing lowers the load, that resumes it, that raises the load, and so on.
    Timer {
        interval: 4000
        running: root.watching && root.hot && !root.busy
        onTriggered: { root.busy = true; hold.restart() }
    }
    Timer {
        id: hold
        interval: 20000
        onRunningChanged: if (!running && root.busy && root.calm) root.busy = false
    }
    onCalmChanged: if (calm && busy && !hold.running) busy = false
}
