import QtQuick
import qs.theme
import qs.services

// The presets of the equalizer as chips, plus "+" to keep the current curve as your own preset.
// Right click on one of your own presets deletes it.
Flow {
    id: root

    property color base: Theme.island

    spacing: 5

    Repeater {
        model: AudioFx.allPresets

        delegate: Rectangle {
            id: pc

            required property var modelData
            readonly property bool sel: AudioFx.preset === modelData.name

            height: 24
            width: lbl.implicitWidth + 22
            radius: 12
            color: sel ? Theme.accent : (pm.containsMouse ? Theme.islandHover : root.base)
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                id: lbl
                anchors.centerIn: parent
                text: pc.modelData.name
                color: pc.sel ? Theme.island : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.bold: pc.sel
            }

            MouseArea {
                id: pm
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        if (AudioFx.isMine(pc.modelData.name)) AudioFx.deleteUserPreset(pc.modelData.name)
                    } else {
                        AudioFx.choose(pc.modelData.name)
                    }
                }
            }
        }
    }

    Rectangle {
        width: 24; height: 24
        radius: 12
        color: sm.containsMouse ? Theme.islandHover : root.base

        Text {
            anchors.centerIn: parent
            text: "+"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }

        MouseArea {
            id: sm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: AudioFx.saveCurrent()
        }
    }
}
