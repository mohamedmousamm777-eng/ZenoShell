import QtQuick
import qs.theme
import qs.services

// Download / upload speed
Capsule {
    id: root

    Component.onCompleted: SysStats.users++
    Component.onDestruction: SysStats.users--

    function fmt(b) {
        if (b < 1024) return Math.round(b) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
        return (b / 1048576).toFixed(1) + " MB/s"
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            text: "↑ " + root.fmt(SysStats.netUp)
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
        Text {
            text: "↓ " + root.fmt(SysStats.netDown)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
