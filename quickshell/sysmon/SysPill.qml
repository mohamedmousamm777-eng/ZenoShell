import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

// Resources pill: comes out of the edge of the screen (left; right in the Vertical style, where the bar is on the left),
// fused with it by two concave curves. A click grows it into the System Monitor.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            // ---- Settings ----
            readonly property bool right: Style.current === "side"
            readonly property int fillet: 14         // concave curves where it joins the edge
            // Vertical style: the screen has a frame of this thickness (same as frameEdge in Bar.qml). The pill is fused with the
            // INNER edge of the frame, not with the edge of the screen, otherwise the curves end up hidden under the frame.
            readonly property real inset: right ? 8 : 0
            readonly property int pillW: 140         // width of the pill
            // Size of the System Monitor (wide styles / Vertical panel); never taller than the screen
            readonly property int monW: right ? 500 : 800
            readonly property int monH: Math.min(right ? 780 : 720, (win.screen ? win.screen.height : 900) - 90)
            readonly property int stripW: 6          // thickness of the sensitive strip on the edge
            readonly property int stripH: 300        // height of the sensitive strip (centered)
            readonly property bool showHandle: true  // small line marking where it opens

            readonly property bool here: SysStats.shown
                && (SysStats.screen === "" || SysStats.screen === modelData.name)
            readonly property bool monitorOn: SysStats.monitorOpen
                && (SysStats.monitorScreen === "" || SysStats.monitorScreen === modelData.name)
            readonly property bool open: here || monitorOn

            // The window is big only while the monitor is open (and a moment after, for the closing animation)
            property bool big: false
            onMonitorOnChanged: {
                if (monitorOn) { bigTimer.stop(); big = true }
                else bigTimer.restart()
            }
            Timer { id: bigTimer; interval: 700; onTriggered: win.big = false }

            // Position: 0 = hidden in the edge, 1 = open. The spring goes past 1 and the pill stretches a little.
            property real reveal: win.open ? 1 : 0
            Behavior on reveal {
                SpringAnimation { spring: 3.0; damping: 0.28; epsilon: 0.002 }
            }

            readonly property real pillLen: col.implicitHeight + 40
            property real depth: win.monitorOn ? win.monW : win.pillW
            property real length: win.monitorOn ? win.monH : win.pillLen
            Behavior on depth  { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on length { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            readonly property real hid: (1 - Math.min(1, win.reveal)) * win.depth            // pushed into the edge
            readonly property real sdepth: win.depth * (win.monitorOn ? 1 : Math.max(1, win.reveal))

            // Only one side is anchored: the compositor centers it vertically
            // While the monitor is open the window covers the whole screen (invisible): a click outside the monitor closes it
            anchors { left: !win.right || win.big; right: win.right || win.big; top: win.big; bottom: win.big }
            implicitWidth: win.big ? win.monW + 80 : win.pillW + 70
            implicitHeight: win.big ? win.monH + win.fillet * 2 + 24 : 480
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top        // does not cover fullscreen games
            WlrLayershell.namespace: "shell-system"
            WlrLayershell.keyboardFocus: win.monitorOn ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // The mouse arrives only here: a strip on the edge (closed) or the whole shape (open)
            mask: Region { item: win.monitorOn ? clickAway : inputArea }

            // Whole window, only while the monitor is open: a click anywhere outside the monitor closes it
            Item {
                id: clickAway
                anchors.fill: parent

                MouseArea {
                    anchors.fill: parent
                    enabled: win.monitorOn
                    onPressed: SysStats.closeMonitor()
                }
            }

            Item {
                id: inputArea

                x: win.open ? shape.x : (win.right ? win.width - win.stripW : 0)
                y: win.open ? shape.y : (win.height - win.stripH) / 2
                width: win.open ? shape.width + win.inset + 1 : win.stripW
                height: win.open ? shape.height : win.stripH

                HoverHandler {
                    id: hh
                    onHoveredChanged: SysStats.setEdge(hovered, win.modelData.name)
                }
            }

            // The monitor stays open until you click outside it (or press Escape / the close button)

            Shortcut {
                sequence: "Escape"
                enabled: win.monitorOn
                onActivated: SysStats.closeMonitor()
            }

            // Small line marking where it opens (disappears when the pill leaves)
            Rectangle {
                visible: win.showHandle
                anchors.verticalCenter: parent.verticalCenter
                x: win.right ? win.width - 3 : -3
                width: 6
                height: 64
                radius: 3
                color: Theme.accent
                opacity: win.open ? 0 : 0.5
                Behavior on opacity { NumberAnimation { duration: 250 } }
            }

            // ---------- The shape, attached to the edge ----------
            AttachedShapeSide {
                id: shape

                x: win.right ? win.width - win.inset - win.sdepth + win.hid : -win.hid
                y: (win.height - height) / 2
                visible: win.open || win.reveal > 0.01
                bodyDepth: win.sdepth + (win.right ? 1 : 0)      // 1 px under the frame: no hairline between the two
                bodyLength: win.length
                fillet: win.fillet
                corner: 26

                // the same shape is drawn for the left edge, mirrored
                transform: Scale { origin.x: shape.width / 2; xScale: win.right ? 1 : -1 }
            }

            MouseArea {
                visible: win.monitorOn
                x: shape.x
                y: shape.y
                width: shape.width + win.inset + 1
                height: shape.height
            }

            // ---------- Pill: the four readings ----------
            Item {
                id: pillBox

                x: win.right ? win.width - win.inset - win.pillW + win.hid + 14 : -win.hid + win.fillet + 12
                y: shape.y + win.fillet + 20
                width: 96
                height: col.implicitHeight
                opacity: win.monitorOn ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Column {
                    id: col

                    width: 96
                    spacing: 12

                    Ring {
                        width: 96
                        height: 96
                        label: "CPU"
                        value: win.here ? SysStats.cpu : 0
                        sweep: 550
                    }

                    Ring {
                        width: 96
                        height: 96
                        label: "RAM"
                        value: win.here ? SysStats.ram : 0
                        tone: Theme.note
                        sweep: 750
                    }

                    Ring {
                        width: 96
                        height: 96
                        label: "DISK"
                        value: win.here ? SysStats.disk : 0
                        sweep: 950
                    }

                    // Network: download and upload speed
                    Rectangle {
                        width: 96
                        height: 70
                        radius: 22
                        color: Theme.surfaceSoft

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "NET"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.bold: true
                            }

                            Row {
                                spacing: 4
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    text: "↓"
                                    color: Theme.accent
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    text: SysStats.fmtRate(SysStats.netDown)
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }

                            Row {
                                spacing: 4
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    text: "↑"
                                    color: Theme.muted
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    text: SysStats.fmtRate(SysStats.netUp)
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }

            // A click on the pill opens the monitor
            MouseArea {
                visible: win.open && !win.monitorOn
                x: shape.x
                y: shape.y + win.fillet
                width: shape.width
                height: shape.height - win.fillet * 2
                cursorShape: Qt.PointingHandCursor
                onClicked: SysStats.openMonitor(win.modelData.name, "")
            }

            // ---------- System Monitor: fixed size, shown by the growing shape ----------
            Item {
                id: monClip

                x: shape.x
                y: shape.y + win.fillet
                width: shape.width
                height: shape.height - win.fillet * 2
                clip: true

                // Created only while the monitor is open (and while it closes): zero cost the rest of the time
                Loader {
                    id: monLoader

                    readonly property real cw: win.monW - 14 - win.fillet - 12
                    active: win.big
                    x: win.right ? monClip.width - 26 - cw : win.fillet + 12
                    y: 14
                    width: cw
                    height: win.monH - 28
                    focus: win.monitorOn
                    opacity: win.monitorOn && win.sdepth > win.monW * 0.5 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    sourceComponent: MonitorView {
                        narrow: win.right
                        focus: true
                        onCloseRequested: SysStats.closeMonitor()
                    }
                }
            }
        }
    }
}
