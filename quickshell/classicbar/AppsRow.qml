import QtQuick
import Quickshell
import qs.theme
import qs.services

// Open apps: click to bring one forward, middle click to close it
Capsule {
    id: root

    visible: Windows.apps.length > 0
    spacing: 8

    Repeater {
        model: Windows.apps.slice(0, 8)

        delegate: Item {
            id: app
            required property var modelData

            width: 24; height: 24
            anchors.verticalCenter: parent.verticalCenter
            scale: m.containsMouse ? 1.12 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }

            Image {
                anchors.fill: parent
                sourceSize: Qt.size(48, 48)
                smooth: true
                source: Quickshell.iconPath(Windows.iconFor(app.modelData.appId), "application-x-executable")
            }
            // marks the app of the focused window
            Rectangle {
                visible: app.modelData.active
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height + 1
                width: 10; height: 3; radius: 2
                color: Theme.accent
            }
            Text {
                visible: app.modelData.count > 1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: -4
                text: app.modelData.count
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.bold: true
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
