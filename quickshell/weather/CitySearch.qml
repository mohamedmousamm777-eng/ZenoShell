import QtQuick
import qs.theme
import qs.services

// Type a city name, pick one from the list
Item {
    id: root

    property color base: Theme.surfaceSoft
    property bool autoFocus: false
    signal chosen()
    signal escaped()

    implicitWidth: 360
    implicitHeight: 40 + (list.count > 0 ? list.count * 44 + 6 : (note.visible ? 30 : 0))

    function focusField() { input.forceActiveFocus() }
    Component.onCompleted: if (autoFocus) input.forceActiveFocus()
    Component.onDestruction: Weather.search("")

    Rectangle {
        id: field
        width: parent.width
        height: 38
        radius: 19
        color: root.base
        border.width: 1
        border.color: input.activeFocus ? Theme.accent : Theme.border

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            onTextChanged: delay.restart()
            Keys.onEscapePressed: root.escaped()
            Keys.onReturnPressed: if (Weather.results.length > 0) root.pick(Weather.results[0])

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: Weather.tr("search")
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }
    }

    Timer { id: delay; interval: 350; onTriggered: Weather.search(input.text) }

    function pick(r) {
        Weather.setPlace(r.lat, r.lon, r.label, false)
        input.text = ""
        Weather.search("")
        root.chosen()
    }

    Text {
        id: note
        y: 46
        visible: input.text.trim().length >= 2 && !Weather.searching && Weather.results.length === 0
        text: Weather.tr("noResults")
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
        x: 8
    }

    ListView {
        id: list
        y: 44
        width: parent.width
        height: count * 44
        interactive: false
        model: Weather.results

        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: 42
            radius: 14
            color: m.containsMouse ? Theme.islandHover : "transparent"

            Column {
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                width: parent.width - 28
                Text {
                    width: parent.width
                    text: parent.parent.modelData.name
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: parent.parent.modelData.sub
                    visible: text !== ""
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: m
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pick(parent.modelData)
            }
        }
    }
}
