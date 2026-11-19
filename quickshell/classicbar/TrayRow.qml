import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.theme
import qs.services

// Tray icons of the running apps (Spotify, Discord, network applet...)
Capsule {
    id: root

    visible: SystemTray.items.values.length > 0
    spacing: 10

    Repeater {
        model: SystemTray.items.values.slice(0, 8)

        delegate: Item {
            id: ico
            required property var modelData

            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                sourceSize: Qt.size(36, 36)
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
}
