import QtQuick
import qs.theme
import qs.widgets
import qs.weather

// Icon + value: "[icon] 44". With `bubble` the icon sits in a round light disc (Full and Capsules looks).
Row {
    id: root

    property string kind: "cpu"          // a Glyph kind, or "temp"
    property string label: ""
    property bool bubble: true
    property color bubbleColor: Qt.rgba(1, 1, 1, 0.85)
    property color glyphColor: "#1b1b1f"
    property real textSize: 13

    spacing: bubble ? 8 : 5

    Rectangle {
        visible: root.bubble
        anchors.verticalCenter: parent.verticalCenter
        width: 26; height: 26; radius: 13
        color: root.bubbleColor
        Glyph {
            visible: root.kind !== "temp"
            anchors.centerIn: parent
            kind: root.kind
            size: 14
            color: root.glyphColor
        }
        WxIcon {
            visible: root.kind === "temp"
            anchors.centerIn: parent
            width: 14; height: 14
            kind: "l-temp"
            color: root.glyphColor
            lineW: 1.6
        }
    }
    Glyph {
        visible: !root.bubble && root.kind !== "temp"
        anchors.verticalCenter: parent.verticalCenter
        kind: root.kind
        size: 13
        color: Theme.muted
    }
    WxIcon {
        visible: !root.bubble && root.kind === "temp"
        anchors.verticalCenter: parent.verticalCenter
        width: 13; height: 13
        kind: "l-temp"
        color: Theme.muted
        lineW: 1.5
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: root.textSize
    }
}
