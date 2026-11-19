import QtQuick
import qs.theme
import qs.services

// Upload / download speed. `stacked`: two lines with the arrows after the numbers (Full); otherwise one line
Item {
    id: root

    property bool stacked: true

    Component.onCompleted: SysStats.users++
    Component.onDestruction: SysStats.users--

    implicitWidth: stacked ? col.implicitWidth : line.implicitWidth
    implicitHeight: Theme.islandHeight
    width: implicitWidth
    height: implicitHeight

    function fmt(b) {
        if (b < 1024) return Math.round(b) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
        return (b / 1048576).toFixed(1) + " MB/s"
    }

    Column {
        id: col
        visible: root.stacked
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Row {
            spacing: 6
            anchors.right: parent.right
            Text { text: root.fmt(SysStats.netUp); color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 10 }
            Text { text: "⌃"; color: Theme.muted; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            spacing: 6
            anchors.right: parent.right
            Text { text: root.fmt(SysStats.netDown); color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 10 }
            Text { text: "⌄"; color: Theme.muted; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    Row {
        id: line
        visible: !root.stacked
        anchors.verticalCenter: parent.verticalCenter
        spacing: 22
        Row {
            spacing: 8
            Text { text: "↑"; color: Theme.muted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.fmt(SysStats.netUp); color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 12 }
        }
        Row {
            spacing: 8
            Text { text: "↓"; color: Theme.muted; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.fmt(SysStats.netDown); color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 12 }
        }
    }
}
