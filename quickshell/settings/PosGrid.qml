import QtQuick
import qs.theme

// A 3 x 3 grid of dots: where a piece sits on the screen (tl tc tr / cl cc cr / bl bc br)
Rectangle {
    id: root

    property string current: "cc"
    property color base: Theme.island
    signal picked(string code)

    implicitWidth: 78
    implicitHeight: 58
    radius: 8
    color: root.base
    border.width: 1
    border.color: Theme.border

    Grid {
        anchors.centerIn: parent
        columns: 3
        spacing: 6
        Repeater {
            model: ["tl", "tc", "tr", "cl", "cc", "cr", "bl", "bc", "br"]
            delegate: Rectangle {
                required property string modelData
                width: 18; height: 12; radius: 4
                color: root.current === modelData ? Theme.accent : (m.containsMouse ? Theme.islandHover : Theme.surfaceSoft)
                Behavior on color { ColorAnimation { duration: 100 } }
                MouseArea {
                    id: m
                    anchors.fill: parent
                    anchors.margins: -2
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(parent.modelData)
                }
            }
        }
    }
}
