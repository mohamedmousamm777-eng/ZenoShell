import QtQuick
import qs.theme
import qs.services

// Battery number in a white pill with a small tip (laptops only)
Rectangle {
    id: root

    visible: Battery.present
    height: 20
    width: visible ? label.implicitWidth + 18 : 0
    radius: 10
    color: Battery.low ? Theme.danger : "#f2f2f4"

    Text {
        id: label
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -1
        text: Math.round(Battery.percent * 100)
        color: "#16161a"
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.bold: true
    }
    // tip of the battery
    Rectangle {
        anchors.left: parent.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 2; height: 7; radius: 1
        color: parent.color
        opacity: 0.8
    }
}
