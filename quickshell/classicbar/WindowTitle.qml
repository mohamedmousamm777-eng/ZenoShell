import QtQuick
import qs.theme
import qs.services

// App and title of the focused window ("Desktop" when there is none)
Rectangle {
    id: root

    // "Floating" look: the label sits in its own capsule
    readonly property bool boxed: Style.classicVariant === "floating"

    readonly property var focused: Windows.active
    readonly property string appName: focused ? Windows.nameFor(focused.appId || "") : "Desktop"
    readonly property string title: focused ? (focused.title || "") : Compositor.kind

    height: Theme.islandHeight
    width: Math.min(220, Math.max(first.implicitWidth, second.implicitWidth)) + (boxed ? 28 : 0)
    radius: height / 2
    color: boxed ? Theme.island : "transparent"
    border.width: boxed ? 1 : 0
    border.color: Theme.border

    Column {
        x: root.boxed ? 14 : 0
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (root.boxed ? 28 : 0)
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
