pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Your profile (name, place, photo) and how the lock screen looks.
// Saved in ~/.local/state/quickshell/profile.json
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string photoDir: Quickshell.env("HOME") + "/Immagini/Profile"
    readonly property string user: Quickshell.env("USER")

    // ---- profile ----
    property string name: ""            // shown name ("" = the Linux user name)
    property string place: ""           // e.g. "Rome" (shown under the name)
    property string photo: ""           // file name inside photoDir ("" = none: the initial of the name)
    property string shape: "circle"     // circle | rounded | square

    // ---- lock screen ----
    property string lockStyle: "classic"      // classic | giant | terminal
    // where each piece sits: tl tc tr / cl cc cr / bl bc br ("" = the default of the style)
    property string clockPos: ""
    property string loginPos: ""

    readonly property var lockStyles: [
        { id: "classic",  label: "Classic",     hint: "Clock and login side by side" },
        { id: "giant",    label: "Giant clock", hint: "Huge clock, a lock pill that fills with dots" },
        { id: "terminal", label: "Terminal",    hint: "Pixel look with buttons and a login line" }
    ]

    readonly property string shownName: name !== "" ? name : user
    readonly property string photoUrl: photo !== "" ? "file://" + photoDir + "/" + photo : ""
    readonly property real photoRadius: shape === "circle" ? 0.5 : (shape === "rounded" ? 0.22 : 0)

    // default positions per style
    function defClock(style) { return style === "giant" ? "cc" : (style === "terminal" ? "tr" : "cl") }
    function defLogin(style) { return style === "giant" ? "tc" : (style === "terminal" ? "bl" : "cr") }
    readonly property string clockAt: clockPos !== "" ? clockPos : defClock(lockStyle)
    readonly property string loginAt: loginPos !== "" ? loginPos : defLogin(lockStyle)

    // ---- photos found in the folder ----
    property var photos: []

    function refresh() { lister.running = false; lister.running = true }

    Process {
        id: lister
        command: [Quickshell.shellPath("scripts/profile-photos.sh"), root.photoDir]
        stdout: StdioCollector {
            onStreamFinished: root.photos = text.split("\n").filter(l => l !== "")
        }
    }

    // ---- save / load ----
    FileView {
        id: store
        path: root.stateDir + "/profile.json"
        blockLoading: true
    }

    function save() {
        try {
            store.setText(JSON.stringify({ name: name, place: place, photo: photo, shape: shape,
                                           lockStyle: lockStyle, clockPos: clockPos, loginPos: loginPos }))
        } catch (e) { console.log("profile: save:", e) }
    }

    function setName(v) { name = v.trim(); save() }
    function setPlace(v) { place = v.trim(); save() }
    function setPhoto(f) { photo = f; save() }
    function setShape(s) { if (["circle", "rounded", "square"].indexOf(s) >= 0) { shape = s; save() } }
    function setLockStyle(s) {
        for (let i = 0; i < lockStyles.length; i++)
            if (lockStyles[i].id === s) { lockStyle = s; clockPos = ""; loginPos = ""; save(); return true }
        return false
    }
    function setClockPos(p) { clockPos = p; save() }
    function setLoginPos(p) { loginPos = p; save() }
    function resetPositions() { clockPos = ""; loginPos = ""; save() }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", stateDir, photoDir])
        try {
            const d = JSON.parse(store.text())
            if (typeof d.name === "string") name = d.name
            if (typeof d.place === "string") place = d.place
            if (typeof d.photo === "string") photo = d.photo
            if (["circle", "rounded", "square"].indexOf(d.shape) >= 0) shape = d.shape
            for (let i = 0; i < lockStyles.length; i++) if (lockStyles[i].id === d.lockStyle) lockStyle = d.lockStyle
            const ok = /^[tcb][lcr]$/
            if (typeof d.clockPos === "string" && (d.clockPos === "" || ok.test(d.clockPos))) clockPos = d.clockPos
            if (typeof d.loginPos === "string" && (d.loginPos === "" || ok.test(d.loginPos))) loginPos = d.loginPos
        } catch (e) {}
        refresh()
    }
}
