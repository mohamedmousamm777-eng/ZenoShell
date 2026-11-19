import QtQuick
import qs.theme
import qs.services
import qs.widgets

// "Capsules": colored capsules inside dark containers (left and right), workspaces in a black capsule at the center
Item {
    id: root

    property string screenName: ""
    property var clock: null
    readonly property real clockY: 6
    readonly property Item control: ctl
    readonly property Item maskL: groupL
    readonly property Item maskC: ws
    readonly property Item maskR: groupR
    readonly property Item maskT: null
    readonly property Item maskD: null

    readonly property bool idle: clock ? clock.mode === "idle" : true
    readonly property color dark: Theme.mix(Theme.background, "#000000", 0.55)
    readonly property color purple: Theme.mix(Theme.island, Theme.palette.c[5], 0.30)
    readonly property color teal: Theme.mix(Theme.island, Theme.palette.c[4], 0.35)
    readonly property color steel: Theme.mix(Theme.island, Theme.palette.c[6], 0.22)
    readonly property color lit: Theme.mix(Theme.accent, "#ffffff", 0.45)
    readonly property int ch: 32           // capsule height

    LookTime { id: tm }

    Timer {
        interval: 1500; repeat: true
        running: root.clock !== null && root.clock.monthMode && !root.clock.dayMode
        onTriggered: if (!root.clock.hovered) root.clock.monthMode = false
    }

    component Pill: Rectangle {
        default property alias content: inner.data
        property int padX: 14
        property int gap: 12
        height: root.ch
        radius: height / 2
        width: inner.implicitWidth + padX * 2
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Row {
            id: inner
            x: parent.padX
            anchors.verticalCenter: parent.verticalCenter
            spacing: parent.gap
        }
    }

    // ---- left container ----
    Rectangle {
        id: groupL
        x: 8; y: 2
        height: 40
        width: leftRow.implicitWidth + 8
        radius: 20
        color: root.dark
        border.width: 1
        border.color: Theme.border
        opacity: root.idle ? 1 : 0.0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Row {
            id: leftRow
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Component.onCompleted: SysStats.users++
            Component.onDestruction: SysStats.users--

            Item {
                width: root.ch; height: root.ch
                z: 5
                MediaIsland {
                    y: -1
                    screenName: root.screenName
                    restColor: Theme.mix(Theme.island, Theme.accent, 0.30)
                    onLauncherRequested: {
                        UiState.launcherScreen = root.screenName
                        UiState.powerOpen = false
                        UiState.launcherOpen = !UiState.launcherOpen
                    }
                }
            }
            Pill {
                color: root.purple
                gap: 14
                Stat { anchors.verticalCenter: parent.verticalCenter; kind: "bell"; label: String(NotifCenter.count); bubbleColor: Qt.rgba(1, 1, 1, 0.55) }
                Stat { anchors.verticalCenter: parent.verticalCenter; kind: "cpu"; label: String(Math.round(SysStats.cpu * 100)); bubbleColor: Qt.rgba(1, 1, 1, 0.55) }
                Stat { visible: SysStats.maxTemp > 0; anchors.verticalCenter: parent.verticalCenter; kind: "temp"; label: String(Math.round(SysStats.maxTemp)); bubbleColor: Qt.rgba(1, 1, 1, 0.85) }
            }
            Pill {
                color: root.teal
                padX: 12
                gap: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Capture.recording ? "● " + Capture.timeText : tm.date("ddd, MM/dd")
                    color: Capture.recording ? Theme.danger : Theme.foreground
                    font.family: Theme.fontFamily; font.pixelSize: 13
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: hh.implicitWidth + 22; height: 26; radius: 13
                    color: root.lit
                    Text {
                        id: hh
                        anchors.centerIn: parent
                        text: tm.hhmm
                        color: "#10202b"
                        font.family: Theme.fontFamily; font.pixelSize: 13; font.bold: true
                    }
                }
                Rectangle {
                    visible: tm.ampm !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 13
                    color: Theme.mix(root.purple, "#000000", 0.2)
                    Text { anchors.centerIn: parent; text: tm.ampm; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 11 }
                }
                // click: calendar, right click: recording menu (handlers act on the row, not as a child item)
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onTapped: if (root.clock) root.clock.monthMode = true
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: { UiState.recMenuScreen = root.screenName; UiState.recMenuOpen = true }
                }
            }
        }
    }

    // ---- center ----
    WorkspaceDots {
        id: ws
        x: (root.width - width) / 2
        y: 4
        height: 36
        look: "capsules"
        screenName: root.screenName
        opacity: root.idle ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // ---- right container ----
    Rectangle {
        id: groupR
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 2
        height: 40
        width: rightRow.implicitWidth + 8
        radius: 20
        color: root.dark
        border.width: 1
        border.color: Theme.border

        Row {
            id: rightRow
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Pill {
                color: Theme.mix(Theme.island, "#000000", 0.1)
                padX: 18
                Net { anchors.verticalCenter: parent.verticalCenter; stacked: false }
            }
            Pill {
                visible: tray.any
                color: root.steel
                padX: 12
                Tray { id: tray; anchors.verticalCenter: parent.verticalCenter; iconSize: 18 }
            }
            Item {
                width: ctl.closedW; height: root.ch
                z: 5
                ControlIsland {
                    id: ctl
                    anchors.right: parent.right
                    y: -1
                    classic: true
                    look: "capsules"
                    closedTint: root.purple
                }
            }
            Pill {
                visible: Battery.present
                color: root.teal
                padX: 8
                Batt { anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
}
