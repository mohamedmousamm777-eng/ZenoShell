import QtQuick
import qs.theme
import qs.widgets
import qs.weather

// Small icon with a value: "[icon] 44"
Row {
    id: root

    property string kind: "cpu"       // a Glyph kind, or "temp"
    property string label: ""
    property color tint: Theme.muted

    spacing: 6

    Glyph {
        visible: root.kind !== "temp"
        anchors.verticalCenter: parent.verticalCenter
        kind: root.kind
        size: 15
        color: root.tint
    }
    WxIcon {
        visible: root.kind === "temp"
        anchors.verticalCenter: parent.verticalCenter
        width: 15; height: 15
        kind: "l-temp"
        color: root.tint
        lineW: 1.6
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.bold: true
    }
}
