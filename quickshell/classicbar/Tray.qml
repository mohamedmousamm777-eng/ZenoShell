import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.theme
import qs.services

// Tray icons (Discord, Spotify...) and, after them, the open apps that have no tray icon of their own
Row {
    id: root

    property real iconSize: 18

    readonly property var trayItems: SystemTray.items.values.slice(0, 8)
    // open apps (one per app) except the ones already shown by the tray
    readonly property var openApps: {
        const out = []
        const tray = SystemTray.items.values
        const apps = Windows.apps
        for (let i = 0; i < apps.length && out.length < 6; i++) {
            const id = (apps[i].appId || "").toLowerCase()
            let dup = false
            for (let t = 0; t < tray.length; t++) {
                const tid = ((tray[t].id || "") + " " + (tray[t].title || "")).toLowerCase()
                if (id && (tid.indexOf(id) >= 0 || id.indexOf((tray[t].id || "~").toLowerCase()) >= 0)) { dup = true; break }
            }
            if (!dup) out.push(apps[i])
        }
        return out
    }
    readonly property bool any: trayItems.length > 0 || openApps.length > 0

    visible: any
    spacing: 10

    Repeater {
        model: root.trayItems

        delegate: Item {
            id: ico
            required property var modelData

            width: root.iconSize; height: root.iconSize
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                sourceSize: Qt.size(48, 48)
                smooth: true
                source: ico.modelData.icon
            }

            QsMenuAnchor {
                id: menu
                menu: ico.modelData.menu
                anchor.item: ico
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton || ico.modelData.onlyMenu) {
                        if (ico.modelData.hasMenu) menu.open()
                    } else if (mouse.button === Qt.MiddleButton) ico.modelData.secondaryActivate()
                    else ico.modelData.activate()
                }
            }
        }
    }

    // open apps: click = bring forward, middle click = close
    Repeater {
        model: root.openApps

        delegate: Item {
            id: app
            required property var modelData

            width: root.iconSize; height: root.iconSize
            anchors.verticalCenter: parent.verticalCenter
            scale: m.containsMouse ? 1.12 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }

            Image {
                anchors.fill: parent
                sourceSize: Qt.size(48, 48)
                smooth: true
                source: Quickshell.iconPath(Windows.iconFor(app.modelData.appId), "application-x-executable")
            }
            Rectangle {
                visible: app.modelData.active
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height + 1
                width: 8; height: 2; radius: 1
                color: Theme.accent
            }
            MouseArea {
                id: m
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) Windows.closeApp(app.modelData.appId)
                    else Windows.focusApp(app.modelData.appId)
                }
            }
        }
    }
}
