import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.widgets

// "Giant clock": a huge clock, and a small black pill with a lock that fills with dots while you type
Item {
    id: root

    property var host: null            // LockView (typed text, state, positions)

    readonly property string typed: host ? host.typed : ""
    readonly property bool typing: typed.length > 0

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property string full: Qt.formatDateTime(clock.date, Settings.timeFormat)
    readonly property string hhmm: full.split(" ")[0]
    readonly property string ampm: full.indexOf(" ") > 0 ? full.split(" ")[1] : ""

    // ---- clock ----
    Item {
        id: clockBox
        width: timeText.implicitWidth
        height: timeText.implicitHeight
        x: host ? host.posX(Profile.clockAt, width, root.width * 0.06) : 0
        y: host ? host.posY(Profile.clockAt, height, root.height * 0.08) : 0

        // soft shadow: the same text, a bit lower and dark
        Text {
            y: 7
            text: timeText.text
            color: Qt.rgba(0, 0, 0, 0.32)
            font: timeText.font
        }
        Text {
            id: timeText
            text: root.hhmm
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Math.min(root.width * 0.2, root.height * 0.33)
            font.weight: Font.Black
        }
        Text {
            visible: root.ampm !== ""
            anchors.left: timeText.right
            anchors.leftMargin: 10
            anchors.baseline: timeText.baseline
            text: root.ampm
            color: Theme.accent
            opacity: 0.8
            font.family: Theme.fontFamily
            font.pixelSize: timeText.font.pixelSize * 0.22
            font.weight: Font.Bold
        }
    }

    // ---- pill: lock -> dots ----
    Rectangle {
        id: pill
        readonly property int n: Math.min(root.typed.length, 18)
        width: root.typing ? Math.max(52, 26 + n * 13) : 52
        height: 30
        radius: 15
        color: Qt.rgba(0.03, 0.03, 0.04, 0.96)
        border.width: (host && host.failed) ? 1.5 : 0
        border.color: Theme.danger
        x: host ? host.posX(Profile.loginAt, width, root.width * 0.06) : 0
        y: host ? host.posY(Profile.loginAt, height + 22, root.height * 0.05) : 0
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        transform: Translate { id: shake }

        Glyph {
            anchors.centerIn: parent
            kind: "lock"
            size: 14
            color: "#f2f2f4"
            opacity: root.typing ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6
            opacity: root.typing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Repeater {
                model: pill.n
                Rectangle {
                    required property int index
                    width: index === pill.n - 1 ? 5 : 7
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#f2f2f4"
                    opacity: (host && host.checking) ? 0.5 : 1
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 8
            text: host ? host.status : ""
            color: Theme.danger
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        MouseArea { anchors.fill: parent; onClicked: if (host) host.focusInput() }
    }

    Connections {
        target: root.host
        function onFailCountChanged() { shakeAnim.restart() }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shake; property: "x"; to: -12; duration: 55 }
        NumberAnimation { target: shake; property: "x"; to: 12; duration: 90 }
        NumberAnimation { target: shake; property: "x"; to: -7; duration: 75 }
        NumberAnimation { target: shake; property: "x"; to: 7; duration: 75 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 55 }
    }
}
