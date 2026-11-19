import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.services

// Small selector: a circle for every image of ~/Immagini/Profile, the first one is "no photo" (your initial)
Flow {
    id: root

    spacing: 10

    readonly property int size: 46
    readonly property real r: Profile.photoRadius

    // no photo
    Item {
        width: root.size; height: root.size
        Rectangle {
            anchors.fill: parent
            radius: root.size * root.r
            color: Theme.surfaceSoft
            border.width: Profile.photo === "" ? 2 : 1
            border.color: Profile.photo === "" ? Theme.accent : Theme.border
            Text {
                anchors.centerIn: parent
                text: Profile.shownName.charAt(0).toUpperCase()
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.bold: true
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Profile.setPhoto("") }
    }

    Repeater {
        model: Profile.photos

        delegate: Item {
            id: ph
            required property string modelData
            readonly property bool on: Profile.photo === modelData
            width: root.size; height: root.size
            scale: m.containsMouse ? 1.08 : 1
            Behavior on scale { NumberAnimation { duration: 100 } }

            ClippingRectangle {
                anchors.fill: parent
                radius: root.size * root.r
                color: Theme.surfaceSoft
                border.width: ph.on ? 2 : 1
                border.color: ph.on ? Theme.accent : Theme.border
                Image {
                    anchors.fill: parent
                    source: "file://" + Profile.photoDir + "/" + ph.modelData
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            MouseArea {
                id: m
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Profile.setPhoto(ph.modelData)
            }
        }
    }
}
