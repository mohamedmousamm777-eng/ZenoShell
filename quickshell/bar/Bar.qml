import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.widgets

Scope {
    // Start the lid watcher (Lid service)
    property bool lidActive: Lid.enabled

    // Vertical style: reserve the work area (bar on the left, thin frame on the other sides)
    Variants {
        model: Style.current === "side" ? Quickshell.screens : []

        Scope {
            id: reserve

            required property var modelData

            EdgeReserve { screen: reserve.modelData; edge: "left"; size: 46 }
            EdgeReserve { screen: reserve.modelData; edge: "top"; size: 8 }
            EdgeReserve { screen: reserve.modelData; edge: "right"; size: 8 }
            EdgeReserve { screen: reserve.modelData; edge: "bottom"; size: 8 }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            // Vertical style: the window covers the whole screen (frame + bar + panels); the work area is
            // reserved by the thin windows of EdgeReserve
            readonly property bool sideStyle: Style.current === "side"

            anchors {
                top: true
                left: true
                right: true
                bottom: win.sideStyle
            }
            margins {
                top: (win.sideStyle || win.attachedDash) ? 0 : Theme.topMargin
            }

            // Style chosen from the picker (qs ipc call style toggle)
            readonly property bool classic: Style.current === "classic"
            readonly property bool dashStyle: Style.current === "dash"
            // Dashboard "Attached" version: the bar is fused with the top edge of the screen
            readonly property bool attachedDash: dashStyle && Style.dashAttached
            // The island that drives keyboard shortcuts (Alt+1/2/3, Esc)
            // (the islands of the styles that are not in use do not exist: `ctl` is null until the active one is created)
            readonly property var ctl: win.sideStyle ? popouts.item : (win.dashStyle ? dash.item : control.item)
            readonly property bool ctlExpanded: win.ctl ? win.ctl.expanded === true : false
            readonly property bool ctlNeedsKeyboard: win.ctl ? win.ctl.needsKeyboard === true : false
            readonly property bool dashOpen: dash.item ? dash.item.mode === "open" : false
            readonly property bool popExpanded: popouts.item ? popouts.item.expanded === true : false
            readonly property bool popWantsKeyboard: popouts.item ? popouts.item.wantsKeyboard === true : false
            // Islands of the Island / Classic styles
            readonly property bool islands: !win.dashStyle && !win.sideStyle

            // Fixed transparent window: the islands are what grows
            implicitWidth: 600
            implicitHeight: 620
            color: "transparent"

            exclusionMode: ExclusionMode.Normal
            // -1: in the Vertical style the window covers the whole screen, ignoring the zones reserved by EdgeReserve
            exclusiveZone: win.sideStyle ? -1 : Theme.islandHeight

            // Launcher, power, authentication: exclusive keyboard (you can type right away).
            // Wi-Fi password: only on request.
            WlrLayershell.keyboardFocus: (clock.wantsKeyboard || win.typeToLaunch || (win.sideStyle ? win.popWantsKeyboard : win.ctlExpanded)) ? WlrKeyboardFocus.Exclusive
                                         : (win.ctlNeedsKeyboard ? WlrKeyboardFocus.OnDemand
                                                                  : WlrKeyboardFocus.None)

            // Empty desktop (no window on this monitor's active workspace)
            readonly property bool typeToLaunch: Compositor.emptyDesktop(win.modelData.name)

            onTypeToLaunchChanged: if (typeToLaunch) typer.forceActiveFocus()

            // Typing on the empty desktop opens the launcher with what you typed
            Item {
                id: typer
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    // Control island open: Alt+1/2/3 switches page, Esc closes it
                    if (win.ctlExpanded) {
                        if ((event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                            win.ctl.gotoPage(event.key - Qt.Key_1)
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Escape) {
                            win.ctl.close()
                            event.accepted = true
                            return
                        }
                    }
                    const t = event.text
                    const mods = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)
                    if (!win.typeToLaunch || mods !== 0) return
                    if (t.length !== 1 || t < " " || t === " " || t === "\u007f") return

                    UiState.launcherInitial = t
                    UiState.launcherScreen = win.modelData.name
                    UiState.powerOpen = false
                    UiState.launcherOpen = true
                    event.accepted = true
                }
            }

            // With the control island open the bar listens for keys (Alt+1/2/3)
            Connections {
                target: win.ctl
                function onExpandedChanged() {
                    if (win.ctlExpanded && !win.sideStyle) typer.forceActiveFocus()
                }
            }

            // Same for the launcher / power panel of the Vertical style
            Connections {
                target: popouts.item
                function onExpandedChanged() {
                    if (!win.popExpanded && win.typeToLaunch) typer.forceActiveFocus()
                }
            }

            // Once the launcher is closed on an empty desktop, the bar listens again
            Connections {
                target: clock
                function onWantsKeyboardChanged() {
                    if (!clock.wantsKeyboard && win.typeToLaunch) typer.forceActiveFocus()
                }
            }

            // Clicks pass through everything except the islands/pills
            mask: Region {
                Region { item: media.item }
                Region { item: clock }
                Region { item: control.item }
                Region { item: dash.item }
                Region { item: side.item }
                Region { item: popouts.item ? popouts.item.panel : null }
                Region { item: dismiss }
                Region { item: wsDots.item }
            }

            Item {
                id: stage
                anchors.fill: parent

                // "Island" style: the three islands centered at the top, as before
                readonly property real islandsW: media.w + clock.width + control.w + Theme.gap * 2
                readonly property real startX: (width - islandsW) / 2

                // Dashboard open: a click anywhere else closes it (covers the whole window only while open)
                Item {
                    id: dismiss
                    z: -1
                    width: ((win.dashStyle && win.dashOpen) || (win.sideStyle && win.popExpanded)) ? stage.width : 0
                    height: ((win.dashStyle && win.dashOpen) || (win.sideStyle && win.popExpanded)) ? stage.height : 0

                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (win.ctl) win.ctl.close()
                    }
                }

                // Music = launcher: without a player it is the circle that opens the launcher, with music it becomes the card.
                // In the classic bar it sits at the far left (and above the workspaces when it opens)
                Loader {
                    id: media
                    // size of the island (0 while it does not exist); the Loader is only its anchor point
                    readonly property real w: item ? item.width : 0
                    readonly property real h: item ? item.height : 0
                    active: win.islands
                    z: 5
                    x: win.classic ? 14 : stage.startX
                    sourceComponent: MediaIsland {
                        onLauncherRequested: {
                            UiState.launcherScreen = win.modelData.name
                            UiState.powerOpen = false
                            UiState.launcherOpen = !UiState.launcherOpen
                        }
                    }
                }

                Clock {
                    id: clock
                    // dashboard: the clock island only shows up for launcher, power, recording menu, toasts...
                    visible: win.islands || clock.special
                    attachedPanels: win.sideStyle
                    screenName: win.modelData.name
                    // classic: the clock is always at the center of the screen
                    x: (win.classic || win.dashStyle || win.sideStyle) ? (stage.width - clock.width) / 2 + (win.sideStyle ? side.width / 2 : 0) : media.x + media.w + Theme.gap
                    y: 0
                }

                // Attached Dashboard: the menus (launcher, power, themes...) come out of the edge with the same shape
                AttachedShape {
                    visible: win.attachedDash && clock.visible
                    z: -0.4
                    x: clock.x - fillet
                    y: clock.y
                    bodyWidth: clock.width
                    bodyHeight: clock.height
                    corner: clock.corner
                    edgeColor: clock.edgeColor
                }

                // Workspaces on the left, next to the launcher (classic bar only)
                Loader {
                    id: wsDots
                    // size of the island (0 while it does not exist); the Loader is only its anchor point
                    readonly property real w: item ? item.width : 0
                    readonly property real h: item ? item.height : 0
                    active: win.classic
                    x: 14 + Theme.islandHeight + Theme.gap
                    y: 0
                    sourceComponent: WorkspaceDots { screenName: win.modelData.name }
                }

                // Attached Dashboard: the shape (with the curves where it meets the edge) is drawn behind the island
                AttachedShape {
                    visible: win.attachedDash && dash.visible && dash.item !== null
                    z: -0.4
                    x: dash.x - fillet
                    y: dash.y
                    bodyWidth: dash.w
                    bodyHeight: dash.h
                    corner: dash.item ? dash.item.corner : 18
                    edgeColor: dash.item ? dash.item.edgeColor : Theme.border
                    edgeWidth: dash.item ? dash.item.edgeWidth : 1
                }

                Loader {
                    id: dash
                    // size of the island (0 while it does not exist); the Loader is only its anchor point
                    readonly property real w: item ? item.width : 0
                    readonly property real h: item ? item.height : 0
                    active: win.dashStyle
                    visible: !clock.special
                    x: (stage.width - dash.w) / 2
                    y: 0
                    sourceComponent: DashIsland { screenName: win.modelData.name }
                }

                // ---- Vertical style: frame + bar + panels ----
                readonly property real frameEdge: 8

                Loader {
                    id: frame
                    active: win.sideStyle
                    z: -0.5
                    anchors.fill: parent
                    sourceComponent: ScreenFrame {
                        anchors.fill: parent
                        barW: side.width
                        edge: stage.frameEdge
                        radius: 22
                    }
                }

                Loader {
                    id: side
                    active: win.sideStyle
                    width: 46
                    height: parent.height
                    x: 0
                    y: 0
                    readonly property bool hovered: item ? item.hovered === true : false
                    sourceComponent: SideRail {
                        anchors.fill: parent
                        screenName: win.modelData.name
                        current: popouts.item ? popouts.item.current : ""
                        onRequest: (name, cy) => { if (popouts.item) popouts.item.activate(name, cy) }
                        onPeek: (name, cy) => { if (popouts.item) popouts.item.hoverOpen(name, cy) }
                        onUnpeek: { if (popouts.item) popouts.item.hoverCancel() }
                    }
                }

                Loader {
                    id: popouts
                    active: win.sideStyle
                    anchors.fill: parent
                    sourceComponent: Popouts {
                        anchors.fill: parent
                        screenName: win.modelData.name
                        barW: side.width
                        edge: stage.frameEdge
                        stageH: stage.height
                        railHovered: side.hovered
                    }
                }

                Loader {
                    id: control
                    // size of the island (0 while it does not exist); the Loader is only its anchor point
                    readonly property real w: item ? item.width : 0
                    readonly property real h: item ? item.height : 0
                    active: win.islands
                    x: win.classic ? stage.width - 14 - control.w : clock.x + clock.width + Theme.gap
                    y: 0
                    sourceComponent: ControlIsland { classic: win.classic }
                }
            }
        }
    }
}
