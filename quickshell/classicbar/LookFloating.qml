import QtQuick
import qs.theme
import qs.services
import qs.widgets

// "Floating": separate rounded boxes with a margin from the edges. Left: window label. Center: workspace pills.
// Right: one box with stats, quick settings, battery and date. The dock is in Dock.qml.
Item {
    id: root

    property string screenName: ""
    property var clock: null
    readonly property real clockY: 6
    readonly property Item control: ctl
    readonly property Item maskL: labelBox
    readonly property Item maskC: ws
    readonly property Item maskR: groupR
    readonly property Item maskT: mediaSlot
    readonly property Item maskD: null

    readonly property bool idle: clock ? clock.mode === "idle" : true
    readonly property color dark: Qt.rgba(Theme.background.r * 0.4, Theme.background.g * 0.4, Theme.background.b * 0.4, 0.94)
    readonly property int bh: 36

    LookTime { id: tm }

    Timer {
        interval: 1500; repeat: true
        running: root.clock !== null && root.clock.monthMode && !root.clock.dayMode
        onTriggered: if (!root.clock.hovered) root.clock.monthMode = false
    }

    // ---- left: "Desktop / niri" ----
    Rectangle {
        id: labelBox
        x: 8; y: 6
        height: root.bh
        width: title.width + 28
        radius: 12
        color: root.dark
        opacity: root.idle ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Title { id: title; x: 14; maxW: 200; anchors.verticalCenter: parent.verticalCenter }
    }

    // Music (only when something is playing; otherwise the launcher is in the dock)
    Item {
        id: mediaSlot
        x: labelBox.x + labelBox.width + 8
        y: 7
        z: 5
        width: Media.active ? Theme.islandHeight : 0
        height: Theme.islandHeight
        visible: Media.active
        MediaIsland {
            screenName: root.screenName
            onLauncherRequested: {
                UiState.launcherScreen = root.screenName
                UiState.powerOpen = false
                UiState.launcherOpen = !UiState.launcherOpen
            }
        }
    }

    // ---- center ----
    WorkspaceDots {
        id: ws
        x: (root.width - width) / 2
        y: 6
        height: root.bh
        look: "floating"
        screenName: root.screenName
        opacity: root.idle ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // ---- right ----
    Rectangle {
        id: groupR
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 6
        height: root.bh
        width: row.implicitWidth + 32
        radius: 14
        color: root.dark
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            id: row
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            Component.onCompleted: SysStats.users++
            Component.onDestruction: SysStats.users--

            Stat { visible: NotifCenter.count > 0; anchors.verticalCenter: parent.verticalCenter; bubble: false; kind: "bell"; label: String(NotifCenter.count); textSize: 11 }
            Stat { anchors.verticalCenter: parent.verticalCenter; bubble: false; kind: "cpu"; label: Math.round(SysStats.cpu * 100) + "%"; textSize: 11 }
            Stat { anchors.verticalCenter: parent.verticalCenter; bubble: false; kind: "ram"; label: Math.round(SysStats.ramUsed / Math.max(1, SysStats.ramTotal) * 100) + "%"; textSize: 11 }
            Item {
                width: ctl.closedW; height: root.bh
                z: 5
                ControlIsland {
                    id: ctl
                    anchors.right: parent.right
                    y: 1
                    classic: true
                    look: "floating"
                }
            }
            Row {
                visible: Battery.present
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                BatteryIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    percent: Battery.percent
                    charging: Battery.charging
                    width: 18; height: 9
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Battery.percent * 100) + " %"
                    color: Theme.foreground
                    font.family: Theme.fontFamily; font.pixelSize: 11
                }
            }
            Text {
                id: dt
                anchors.verticalCenter: parent.verticalCenter
                text: Capture.recording ? "● " + Capture.timeText : tm.date("dddd dd, ") + tm.hhmm + (tm.ampm ? " " + tm.ampm : "")
                color: Capture.recording ? Theme.danger : Theme.foreground
                font.family: Theme.fontFamily; font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) { UiState.recMenuScreen = root.screenName; UiState.recMenuOpen = true }
                        else if (root.clock) root.clock.monthMode = true
                    }
                }
            }
        }
    }
}
