import QtQuick
import qs.theme
import qs.services

// Base of the pieces of the Classic looks: a capsule (dark, with a border), or just the content in the "Full" look
Rectangle {
    id: root

    readonly property bool plain: Style.classicPlain
    default property alias content: row.data
    property int spacing: 12
    readonly property int pad: plain ? 2 : 14

    height: Theme.islandHeight
    width: row.implicitWidth + pad * 2
    radius: height / 2
    color: plain ? "transparent" : Theme.island
    border.width: plain ? 0 : 1
    border.color: Theme.border

    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Row {
        id: row
        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing
    }
}
