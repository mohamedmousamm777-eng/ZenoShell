import QtQuick
import qs.theme
import qs.services
import qs.widgets

// "Full": transparent bar. Left: launcher, stats, window title. Center: time | workspaces in a notch | date. Right: network, tray, quick settings, battery.
Item {
    id: root

    property string screenName: ""
    property var clock: null
    readonly property real clockY: 0
    readonly property Item control: ctl
    readonly property Item maskL: leftRow
    readonly property Item maskC: notchBox
    readonly property Item maskR: rightRow
    readonly property Item maskT: timeBox
    readonly property Item maskD: dateBox

    readonly property bool idle: clock ? clock.mode === "idle" : true
    readonly property color dark: Qt.rgba(0.03, 0.03, 0.04, 0.96)
    readonly property real fillet: 14

    LookTime { id: tm }

    // The calendar closes by itself if the pointer is not over it
    Timer {
        interval: 1500; repeat: true
        running: root.clock !== null && root.clock.monthMode && !root.clock.dayMode
        onTriggered: if (!root.clock.hovered) root.clock.monthMode = false
    }

    // ---- left ----
    Row {
        id: leftRow
        x: 12
        height: Theme.islandHeight
        spacing: 18

        Item {
            id: mediaSlot
            width: Theme.islandHeight; height: Theme.islandHeight
            z: 5
            MediaIsland {
                screenName: root.screenName
                restColor: Qt.rgba(1, 1, 1, 0.16)
                onLauncherRequested: {
                    UiState.launcherScreen = root.screenName
                    UiState.powerOpen = false
                    UiState.launcherOpen = !UiState.launcherOpen
                }
            }
        }
        Component.onCompleted: SysStats.users++
        Component.onDestruction: SysStats.users--

        Stat { anchors.verticalCenter: parent.verticalCenter; kind: "bell"; label: String(NotifCenter.count) }
        Stat { anchors.verticalCenter: parent.verticalCenter; kind: "cpu"; label: String(Math.round(SysStats.cpu * 100)) }
        Stat { visible: SysStats.maxTemp > 0; anchors.verticalCenter: parent.verticalCenter; kind: "temp"; label: String(Math.round(SysStats.maxTemp)) }
        Title { anchors.verticalCenter: parent.verticalCenter }
    }

    // ---- center ----
    Item {
        id: notchBox
        x: (root.width - width) / 2
        width: ws.width + root.fillet * 2
        height: Theme.islandHeight
        opacity: root.idle ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        AttachedShape {
            bodyWidth: ws.width
            bodyHeight: parent.height
            fillet: root.fillet
            corner: 18
            fillColor: root.dark
            edgeWidth: 0
            edgeColor: "transparent"
        }
        WorkspaceDots {
            id: ws
            x: root.fillet
            look: "full"
            screenName: root.screenName
        }
    }

    Item {
        id: timeBox
        anchors.right: notchBox.left
        anchors.rightMargin: 4
        width: timeT.implicitWidth + 12
        height: Theme.islandHeight
        opacity: root.idle ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Text {
            id: timeT
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Capture.recording ? "● " + Capture.timeText : tm.full
            color: Capture.recording ? Theme.danger : Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
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

    Item {
        id: dateBox
        anchors.left: notchBox.right
        anchors.leftMargin: 4
        width: dateT.implicitWidth + 12
        height: Theme.islandHeight
        opacity: root.idle ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Text {
            id: dateT
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: tm.date("ddd, MM/dd")
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.clock) root.clock.monthMode = true
        }
    }

    // ---- right ----
    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 12
        height: Theme.islandHeight
        spacing: 14

        Net { stacked: true }
        Tray { anchors.verticalCenter: parent.verticalCenter; iconSize: 17 }
        Item {
            id: ctlSlot
            width: ctl.closedW; height: Theme.islandHeight
            z: 5
            ControlIsland {
                id: ctl
                anchors.right: parent.right
                classic: true
                look: "full"
            }
        }
        Batt { anchors.verticalCenter: parent.verticalCenter }
    }
}
