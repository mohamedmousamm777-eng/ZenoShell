import QtQuick
import qs.theme
import qs.services
import qs.widgets

// Battery level (only on laptops)
Rectangle {
    id: root

    visible: Battery.present
    height: Theme.islandHeight
    width: visible ? label.implicitWidth + 26 : 0
    radius: height / 2
    color: Battery.low ? Theme.danger : Theme.accent
    opacity: 0.95

    Text {
        id: label
        anchors.centerIn: parent
        text: Math.round(Battery.percent * 100)
        color: Theme.island
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.bold: true
    }
}
