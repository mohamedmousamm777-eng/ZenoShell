import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.services

Scope {
    id: root

    // <Pictures>/Wallpapers (Pictures / Immagini / ... depending on the system language)
    // and, next to it, <Pictures>/Wallpapers_Video for the animated ones (videos and GIFs)
    property string dirImg: ""
    property string dirVid: ""

    // The picker shows the animated wallpapers (qs ipc call wallpaper video)
    readonly property bool live: UiState.wallpaperLive
    readonly property string dir: live ? dirVid : dirImg

    Process {
        running: true
        command: ["sh", Quickshell.shellPath("scripts/wallpaper-dir.sh")]
        stdout: StdioCollector { onStreamFinished: { const d = text.trim(); if (d !== "") root.dirImg = d } }
    }

    Process {
        running: true
        command: ["sh", Quickshell.shellPath("scripts/wallpaper-dir.sh"), "video"]
        stdout: StdioCollector { onStreamFinished: { const d = text.trim(); if (d !== "") root.dirVid = d } }
    }

    // Still frames of the animated wallpapers (made with ffmpeg by live-thumbs.sh)
    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell-live/thumbs"
    property var thumbs: ({})            // file name -> true, as the frames get ready

    function thumbUrl(name) {
        return thumbs[name] ? "file://" + thumbDir + "/" + encodeURIComponent(name) + ".jpg" : ""
    }

    Process {
        id: thumbProc
        command: ["sh", Quickshell.shellPath("scripts/live-thumbs.sh"), root.dirVid]

        stdout: SplitParser {
            onRead: line => {
                if (line === "") return
                const t = Object.assign({}, root.thumbs)
                t[line] = true
                root.thumbs = t
            }
        }

        // the colors are taken from the frames, so they come last
        onExited: if (root.live) root.startPalettes()
    }

    property int index: 0
    property string currentPath: ""
    property var palettes: ({})          // percorso -> [5 colori]

    readonly property int count: folder.count
    readonly property url currentUrl: folder.count > 0
        ? (live ? thumbUrl(currentName) : folder.get(index, "fileUrl")) : ""
    readonly property string currentName: folder.count > 0 ? folder.get(index, "fileName") : ""

    // ---------- Images in the folder ----------
    FolderListModel {
        id: folder
        folder: root.dir !== "" ? "file://" + root.dir : ""
        nameFilters: root.live ? ["*.mp4", "*.webm", "*.mkv", "*.mov", "*.gif"]
                               : ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: if (root.index >= count) root.index = Math.max(0, count - 1)
    }

    // Current wallpaper (written by apply-wallpaper.sh) and current animated one (apply-live.sh)
    FileView {
        id: cur
        path: Quickshell.env("HOME") + "/.cache/quickshell-wallpaper-current"
        blockLoading: true
    }

    FileView {
        id: curLive
        path: Quickshell.env("HOME") + "/.cache/quickshell-live-current"
        blockLoading: true
        printErrors: false
    }

    // ---------- Palette of each wallpaper (row by row, as they arrive) ----------
    // Starts the colors of the current folder; if a run is going (maybe for the other folder), it is repeated after it
    property string palDir: ""
    property bool palAgain: false
    function startPalettes() {
        if (palProc.running) { palAgain = true; return }
        palDir = live ? thumbDir : dirImg
        palProc.running = true
    }

    Process {
        id: palProc
        // for the animated ones the colors come from their still frames
        command: ["sh", Quickshell.shellPath("scripts/palettes.sh"), root.palDir]
        onExited: if (root.palAgain) { root.palAgain = false; root.palDir = root.live ? root.thumbDir : root.dirImg; running = true }

        stdout: SplitParser {
            onRead: line => {
                const t = line.indexOf("\t")
                if (t < 0) return
                try {
                    const path = line.slice(0, t)
                    const d = JSON.parse(line.slice(t + 1))
                    const c = d.colors
                    const p = Object.assign({}, root.palettes)
                    p[path] = [d.special.background, c.color1, c.color2, c.color4, c.color5]
                    root.palettes = p
                } catch (e) {}
            }
        }
    }

    // ---------- Logica ----------
    function prepare() {
        let c = ""
        try {
            if (live) { curLive.reload(); c = (curLive.text() || "").trim() }
            else { cur.reload(); c = (cur.text() || "").trim() }
        } catch (e) {}
        currentPath = c

        let idx = 0
        for (let i = 0; i < folder.count; i++) {
            if (folder.get(i, "filePath") === c) { idx = i; break }
        }
        index = idx

        if (live) {
            // the folder is made if it does not exist yet; the frames first, then the colors
            Quickshell.execDetached(["mkdir", "-p", dirVid])
            if (!thumbProc.running) thumbProc.running = true
        } else {
            root.startPalettes()
        }
    }

    function open(liveMode) {
        UiState.wallpaperLive = !!liveMode
        UiState.wallpaperScreen = Compositor.focusedMonitor
        UiState.launcherOpen = false
        UiState.powerOpen = false
        prepare()
        UiState.wallpaperOpen = true
    }

    // the same key closes the picker it opened; the other one switches to its own folder
    function toggleMode(liveMode) {
        if (UiState.wallpaperOpen && UiState.wallpaperLive === liveMode) UiState.wallpaperOpen = false
        else open(liveMode)
    }

    function move(d) {
        if (folder.count === 0) return
        index = (index + d + folder.count) % folder.count
    }

    function applyIndex(i) {
        if (i < 0 || i >= folder.count) return
        const path = folder.get(i, "filePath")
        currentPath = path
        if (live) {
            Settings.set("liveEnabled", true)       // choosing one means you want to see it
            Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/apply-live.sh"), path])
        } else {
            Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/apply-wallpaper.sh"), path])
        }
        UiState.wallpaperOpen = false
    }

    // ---------- Comando IPC: qs ipc call wallpaper toggle | video ----------
    // video: the same picker with the animated wallpapers of the Wallpapers_Video folder
    IpcHandler {
        target: "wallpaper"

        function toggle(): void { root.toggleMode(false) }

        function open(): void { root.open(false) }

        function video(): void { root.toggleMode(true) }

        function openvideo(): void { root.open(true) }

        function close(): void { UiState.wallpaperOpen = false }
    }

    // ---------- Full-screen overlay ----------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            readonly property bool here: UiState.wallpaperOpen
                && (UiState.wallpaperScreen === "" || UiState.wallpaperScreen === modelData.name)

            visible: here || content.opacity > 0
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell-wallpaper"
            WlrLayershell.keyboardFocus: win.here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onHereChanged: {
                if (here) {
                    previewCard.show(root.currentUrl)
                    content.forceActiveFocus()
                }
            }

            Item {
                id: content

                anchors.fill: parent
                opacity: win.here ? 1 : 0
                focus: true
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Right) {
                        root.move(1); event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        root.move(-1); event.accepted = true
                    } else if (event.key === Qt.Key_Home) {
                        root.index = 0; event.accepted = true
                    } else if (event.key === Qt.Key_End) {
                        root.index = Math.max(0, root.count - 1); event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.applyIndex(root.index); event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        UiState.wallpaperOpen = false; event.accepted = true
                    }
                }

                // ----- Darkened background (the blur is added by the Hyprland rule) -----
                Rectangle {
                    anchors.fill: parent
                    color: Theme.scrim
                }

                Timer { id: wheelCool; interval: 90 }

                MouseArea {
                    anchors.fill: parent
                    onClicked: UiState.wallpaperOpen = false
                    onWheel: wheel => {
                        if (wheelCool.running) return
                        root.move(wheel.angleDelta.y > 0 ? -1 : 1)
                        wheelCool.start()
                    }
                }

                // ----- Large preview (same proportions as the screen) -----
                ClippingRectangle {
                    id: previewCard

                    readonly property real pw: content.width * 0.60

                    x: (content.width - width) / 2
                    y: content.height * 0.06
                    width: pw
                    height: pw * content.height / content.width
                    radius: 28
                    color: Theme.island
                    border.width: 1
                    border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.18)
                    scale: win.here ? 1 : 0.94
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    property url shown: ""

                    // Crossfade between one wallpaper and the next
                    function show(url) {
                        if (url === shown) return
                        shown = url
                        back.source = front.source
                        front.opacity = 0
                        front.source = url
                    }

                    Image {
                        id: back
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(1600, 1000)
                    }

                    Image {
                        id: front
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(1600, 1000)
                        opacity: 0
                        onStatusChanged: if (status === Image.Ready) fadeIn.restart()
                    }

                    NumberAnimation {
                        id: fadeIn
                        target: front
                        property: "opacity"
                        from: 0; to: 1
                        duration: 200
                    }

                    Connections {
                        target: root
                        function onCurrentUrlChanged() { previewCard.show(root.currentUrl) }
                    }

                    // No images in the folder
                    Text {
                        anchors.centerIn: parent
                        visible: root.count === 0
                        text: root.live ? "No videos or GIFs in " + root.dir : "No wallpapers in " + root.dir
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                }

                // ----- Name and shortcuts under the preview -----
                Text {
                    x: previewCard.x + 6
                    y: previewCard.y + previewCard.height + 14
                    text: root.currentName
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    anchors.right: previewCard.right
                    anchors.rightMargin: 6
                    y: previewCard.y + previewCard.height + 16
                    text: (root.live ? "Animated  ·  " : "")
                          + (root.count > 0 ? (root.index + 1) + "/" + root.count + "  ·  " : "")
                          + "← → browse  ·  Enter apply  ·  Esc close"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                // ----- Carosello: quadrato + badge colori attaccato -----
                ListView {
                    id: strip

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: content.height * 0.06
                    width: content.width
                    height: 130
                    orientation: ListView.Horizontal
                    spacing: 18
                    interactive: false
                    model: folder
                    currentIndex: root.index

                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: width / 2 - 67
                    preferredHighlightEnd: width / 2 + 67
                    highlightMoveDuration: 240

                    delegate: Item {
                        id: card

                        required property int index
                        required property string filePath
                        required property string fileName
                        required property url fileUrl

                        readonly property bool sel: ListView.isCurrentItem
                        readonly property bool isCurrent: filePath === root.currentPath
                        readonly property var pal: root.palettes[root.live ? root.thumbDir + "/" + fileName + ".jpg" : filePath]

                        width: 134
                        height: 130

                        Item {
                            anchors.centerIn: parent
                            width: 134
                            height: 100
                            scale: card.sel ? 1.12 : 1
                            opacity: card.sel ? 1 : 0.7
                            Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: 18
                                color: Theme.island
                                border.width: card.sel ? 2 : 1
                                border.color: card.sel ? Theme.accent : Theme.border

                                // Square: thumbnail
                                Image {
                                    x: 0; y: 0
                                    width: 100; height: 100
                                    source: root.live ? root.thumbUrl(card.fileName) : card.fileUrl
                                    sourceSize: Qt.size(240, 240)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                // Rettangolo adiacente: palette
                                Rectangle {
                                    x: 100; y: 0
                                    width: 34; height: 100
                                    color: Theme.island

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3

                                        Repeater {
                                            model: 5

                                            Rectangle {
                                                width: 22
                                                height: 14
                                                radius: 5
                                                color: card.pal ? card.pal[modelData] : Qt.rgba(1, 1, 1, 0.10)
                                                border.width: 1
                                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                                Behavior on color { ColorAnimation { duration: 250 } }
                                            }
                                        }
                                    }
                                }
                            }

                            // Dot on the currently applied wallpaper
                            Rectangle {
                                x: 100 - 18
                                y: 8
                                width: 10; height: 10
                                radius: 5
                                color: Theme.accent
                                border.width: 2
                                border.color: Theme.island
                                visible: card.isCurrent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.applyIndex(card.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
