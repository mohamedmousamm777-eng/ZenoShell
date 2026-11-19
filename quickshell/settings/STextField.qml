import QtQuick
import qs.theme

// A one-line text field: Enter or leaving the field saves
Rectangle {
    id: root

    property string text: ""
    property string placeholder: ""
    property color base: Theme.island
    signal committed(string value)

    implicitWidth: 220
    implicitHeight: 32
    radius: 16
    color: root.base
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.border

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        text: root.text
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 13
        clip: true
        selectByMouse: true
        onAccepted: { root.committed(text); focus = false }
        onActiveFocusChanged: if (!activeFocus && text !== root.text) root.committed(text)
        Keys.onEscapePressed: { text = root.text; focus = false }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === "" && !input.activeFocus
            text: root.placeholder
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }
}
