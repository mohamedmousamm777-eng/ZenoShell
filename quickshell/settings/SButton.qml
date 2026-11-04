import QtQuick
import qs.theme

// A small button
Rectangle {
    id: root

    property string label: ""
    property bool accent: false
    signal clicked()

    implicitWidth: text.implicitWidth + 28
    implicitHeight: 30
    radius: 15
    color: accent ? (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
                  : (mouse.containsMouse ? Theme.islandHover : Theme.island)
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        id: text
        anchors.centerIn: parent
        text: root.label
        color: root.accent ? Theme.island : Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
