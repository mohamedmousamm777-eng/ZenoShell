import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

// Dock at the bottom of the screen (Classic bar, "Floating" look).
// It shows your favorite apps and the open ones, always visible, and keeps its own space at the bottom
// (windows stop above it).
Scope {
    id: root

    // Pinned apps first, then the open apps that are not pinned
    readonly property var items: {
        const out = []
        const fav = Apps.favorites
        const all = Apps.all
        const used = {}
        for (let i = 0; i < fav.length; i++) {
            let e = null
            for (let k = 0; k < all.length; k++) if (all[k].id === fav[i]) { e = all[k]; break }
            if (!e) continue
            const key = e.id.toLowerCase().replace(/\.desktop$/, "")
            let run = null
            const wins = Windows.apps
            for (let w = 0; w < wins.length; w++) {
                const a = (wins[w].appId || "").toLowerCase()
                if (a === key || a === e.name.toLowerCase()) { run = wins[w]; used[w] = true; break }
            }
            out.push({ appId: run ? run.appId : key, icon: e.icon, name: e.name, entry: e.entry, running: !!run, active: !!run && run.active })
        }
        const wins = Windows.apps
        for (let w = 0; w < wins.length; w++) {
            if (used[w]) continue
            out.push({ appId: wins[w].appId, icon: Windows.iconFor(wins[w].appId), name: Windows.nameFor(wins[w].appId),
                       entry: null, running: true, active: wins[w].active })
        }
        return out
    }

    Variants {
        model: Style.classicVariant === "floating" && Style.current === "classic" ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            anchors { bottom: true; left: true; right: true }
            implicitHeight: 72
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: 72

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "shell-dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Only the dock takes clicks
            mask: Region { item: dock }

            Rectangle {
                id: dock

                width: row.implicitWidth + 20
                height: 54
                radius: 22
                x: (win.width - width) / 2
                y: win.height - height - 8
                color: Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0.88)
                border.width: 1
                border.color: Theme.border

                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Row {
                    id: row
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Launcher
                    Rectangle {
                        width: 38; height: 38; radius: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: lm.containsMouse ? Theme.islandHover : Theme.surfaceSoft
                        Glyph { anchors.centerIn: parent; kind: "grid"; size: 18; color: Theme.foreground }
                        MouseArea {
                            id: lm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                UiState.launcherScreen = win.modelData.name
                                UiState.powerOpen = false
                                UiState.launcherOpen = !UiState.launcherOpen
                            }
                        }
                    }

                    Repeater {
                        model: root.items

                        delegate: Item {
                            id: app
                            required property var modelData
                            width: 42; height: 46
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: icon
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: m.containsMouse ? 0 : 3
                                width: 38; height: 38
                                sourceSize: Qt.size(76, 76)
                                smooth: true
                                scale: m.containsMouse ? 1.12 : 1
                                Behavior on y { NumberAnimation { duration: 120 } }
                                Behavior on scale { NumberAnimation { duration: 120 } }
                                source: Quickshell.iconPath(app.modelData.icon, "application-x-executable")
                            }
                            // open app: dot (longer when it is the focused one)
                            Rectangle {
                                visible: app.modelData.running
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height - 4
                                width: app.modelData.active ? 12 : 5
                                height: 4; radius: 2
                                color: app.modelData.active ? Theme.accent : Theme.muted
                                Behavior on width { NumberAnimation { duration: 140 } }
                            }

                            MouseArea {
                                id: m
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) { Windows.closeApp(app.modelData.appId); return }
                                    if (app.modelData.running && Windows.focusApp(app.modelData.appId)) return
                                    if (app.modelData.entry) Apps.launch(app.modelData.entry)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
