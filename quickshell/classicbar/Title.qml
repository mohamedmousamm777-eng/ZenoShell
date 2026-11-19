import QtQuick
import qs.theme
import qs.services

// App and title of the focused window ("Desktop / niri" when there is none)
Item {
    id: root

    property int maxW: 220

    readonly property var focused: Windows.active
    readonly property string appName: focused ? Windows.nameFor(focused.appId || "") : "Desktop"
    readonly property string title: focused ? (focused.title || "") : Compositor.kind

    implicitHeight: Theme.islandHeight
    implicitWidth: Math.min(maxW, Math.max(first.implicitWidth, second.implicitWidth))
    width: implicitWidth
    height: implicitHeight

    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 0
        Text {
            id: first
            width: parent.width
            text: root.appName
            elide: Text.ElideRight
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
        Text {
            id: second
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }
}
