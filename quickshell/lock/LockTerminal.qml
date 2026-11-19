import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.widgets

// "Terminal": small outlined buttons, your name, a line for the password, a LOG IN button and a pixel-style clock
Item {
    id: root

    property var host: null

    readonly property string typed: host ? host.typed : ""
    readonly property color line: Theme.accent
    readonly property color boxFill: Qt.rgba(0, 0, 0, 0.35)
    // pixel look: a monospace face, capitals, wide spacing (a font of your choice will come later)
    readonly property string face: "monospace"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property string full: Qt.formatDateTime(clock.date, Settings.timeFormat)

    component Btn: Rectangle {
        id: b
        property string label: ""
        signal clicked()
        width: t.implicitWidth + 28
        height: 36
        radius: 4
        color: m.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : root.boxFill
        border.width: 1
        border.color: Qt.rgba(root.line.r, root.line.g, root.line.b, 0.55)
        Text {
            id: t
            anchors.centerIn: parent
            text: b.label
            color: Theme.foreground
            font.family: root.face
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 2
            font.capitalization: Font.AllUppercase
        }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    // ---- top left: session, restart, power ----
    Row {
        x: 56; y: 56
        spacing: 28
        Btn { label: Compositor.kind === "niri" ? "niri" : "hyprland"; onClicked: if (root.host) root.host.focusInput() }
        Btn { label: "restart"; onClicked: Quickshell.execDetached(["systemctl", "reboot"]) }
        Btn { label: "power"; onClicked: Quickshell.execDetached(["systemctl", "poweroff"]) }
    }

    // ---- clock and date ----
    Column {
        id: clockBox
        spacing: 12
        x: host ? host.posX(Profile.clockAt, width, 90) : 0
        y: host ? host.posY(Profile.clockAt, height, 100) : 0
        Text {
            width: Math.max(implicitWidth, dateText.implicitWidth)
            horizontalAlignment: host ? host.alignOf(Profile.clockAt) : Text.AlignRight
            text: root.full
            color: "#f4f4f4"
            font.family: root.face
            font.pixelSize: Math.min(root.width * 0.052, 100)
            font.bold: true
            font.letterSpacing: 4
        }
        Text {
            id: dateText
            width: parent.width
            horizontalAlignment: host ? host.alignOf(Profile.clockAt) : Text.AlignRight
            text: Qt.locale("en_US").toString(clock.date, "dddd, MMM d")
            color: root.line
            font.family: root.face
            font.pixelSize: 15
            font.letterSpacing: 4
            font.capitalization: Font.AllUppercase
        }
    }

    // ---- login: name, line, button ----
    Column {
        id: loginBox
        width: 450
        spacing: 22
        x: host ? host.posX(Profile.loginAt, width, 84) : 0
        y: host ? host.posY(Profile.loginAt, height, 84) : 0
        transform: Translate { id: shake }

        Column {
            spacing: 4
            Text {
                text: Profile.shownName
                color: "#f4f4f4"
                font.family: root.face
                font.pixelSize: 26
                font.bold: true
                font.letterSpacing: 4
                font.capitalization: Font.AllUppercase
            }
            Text {
                visible: Profile.place !== ""
                text: Profile.place
                color: Theme.muted
                font.family: root.face
                font.pixelSize: 12
                font.letterSpacing: 3
                font.capitalization: Font.AllUppercase
            }
        }

        // typed characters shown as dashes, then a blinking cursor, over a line
        Item {
            width: parent.width
            height: 40
            Row {
                id: dashes
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: Math.min(root.typed.length, 28)
                    Rectangle { width: 12; height: 3; color: "#f4f4f4"; opacity: (root.host && root.host.checking) ? 0.5 : 1 }
                }
                Rectangle {
                    width: 2; height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#f4f4f4"
                    SequentialAnimation on opacity {
                        running: true; loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 2
                color: (root.host && root.host.failed) ? Theme.danger : root.line
            }
        }

        Text {
            visible: root.host && root.host.status !== ""
            text: root.host ? root.host.status : ""
            color: Theme.danger
            font.family: root.face
            font.pixelSize: 11
            font.letterSpacing: 2
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            width: 200; height: 50
            radius: 4
            color: lm.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : root.boxFill
            border.width: 1.5
            border.color: root.line
            Text {
                anchors.centerIn: parent
                text: (root.host && root.host.checking) ? "checking" : "log in"
                color: root.line
                font.family: root.face
                font.pixelSize: 13
                font.bold: true
                font.letterSpacing: 4
                font.capitalization: Font.AllUppercase
            }
            MouseArea {
                id: lm
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.host) root.host.submitTyped()
            }
        }
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
