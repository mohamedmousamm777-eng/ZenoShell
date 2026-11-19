import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.services

// Selector of the Dashboard version (Pill / Attached). It lives inside the pill, like the theme selector.
// Arrows browse (shown live), Enter applies, Esc cancels.
Item {
    id: root

    property int sel: 0
    property string original: "pill"

    readonly property bool classic: Style.current === "classic"
    readonly property var items: classic ? Style.classicVariants : Style.dashVariants
    readonly property string currentId: classic ? Style.classicVariant : Style.dashVariant

    implicitWidth: classic ? 600 : 520
    implicitHeight: 190

    function reset() {
        original = currentId
        sel = 0
        for (let i = 0; i < items.length; i++)
            if (items[i].id === currentId) sel = i
        focusTimer.restart()
    }

    Timer {
        id: focusTimer
        interval: 40
        onTriggered: if (root.visible && Style.variantOpen) keys.forceActiveFocus()
    }
    onVisibleChanged: if (visible) focusTimer.restart()

    // The cards move first; the bar changes shape when the motion is over
    Timer {
        id: applyTimer
        interval: 230
        onTriggered: root.applyNow()
    }

    function applyNow() {
        applyTimer.stop()
        Style.setVariant(items[sel].id)
    }

    function go(i) {
        const n = items.length
        sel = ((i % n) + n) % n
        applyTimer.restart()
    }

    function close(keep) {
        if (keep) applyNow()
        else { applyTimer.stop(); Style.setVariant(original) }
        Style.variantOpen = false
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) root.close(false)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.close(true)
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) root.go(root.sel - 1)
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) root.go(root.sel + 1)
            else return
            event.accepted = true
        }
    }

    Text {
        x: 24; y: 18
        text: root.classic ? "Classic" : "Dashboard"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.bold: true
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: 21
        text: (root.sel + 1) + "/" + root.items.length
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 50
        spacing: 14

        Repeater {
            model: root.items

            delegate: Rectangle {
                id: opt

                required property var modelData
                required property int index

                readonly property bool chosen: root.sel === index
                readonly property bool current: root.currentId === modelData.id

                width: root.classic ? 134 : 200
                height: 92
                radius: 16
                color: optMouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft
                border.width: chosen ? 2 : 0
                border.color: Theme.accent
                opacity: chosen ? 1 : 0.62
                Behavior on opacity { NumberAnimation { duration: 200 } }
                scale: chosen ? 1.0 : 0.94
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                // drawn preview
                Item {
                    x: 14; y: 10
                    width: parent.width - 28
                    height: 40

                    // pill
                    Rectangle {
                        visible: opt.modelData.id === "pill"
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 6
                        width: 96; height: 20; radius: 10
                        color: Theme.island
                        border.width: 1
                        border.color: Theme.border
                        Rectangle { x: 10; y: 8; width: 18; height: 4; radius: 2; color: Theme.accent }
                        Rectangle { x: 40; y: 7; width: 16; height: 6; radius: 3; color: Theme.foreground }
                        Rectangle { x: parent.width - 24; y: 7; width: 14; height: 6; radius: 3; color: Theme.muted }
                    }

                    // attached bar, with the curves at the edge
                    Item {
                        visible: opt.modelData.id === "attached"
                        anchors.fill: parent
                        clip: true

                        AttachedShape {
                            x: (parent.width - 96) / 2 - fillet
                            y: 0
                            bodyWidth: 96
                            bodyHeight: 26
                            fillet: 8
                            corner: 10
                            fillColor: Theme.island
                            edgeColor: Theme.border
                        }
                        Rectangle { x: (parent.width - 96) / 2 + 10; y: 11; width: 18; height: 4; radius: 2; color: Theme.accent }
                        Rectangle { x: (parent.width - 96) / 2 + 40; y: 10; width: 16; height: 6; radius: 3; color: Theme.foreground }
                        Rectangle { x: (parent.width - 96) / 2 + 96 - 24; y: 10; width: 14; height: 6; radius: 3; color: Theme.muted }
                    }

                    // ---- Classic looks ----
                    Item {
                        visible: opt.modelData.id === "bar"
                        anchors.fill: parent
                        Rectangle { x: 2; y: 8; width: 14; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                        Rectangle { x: 20; y: 8; width: 30; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                        Rectangle { x: parent.width / 2 - 14; y: 8; width: 28; height: 14; radius: 7; color: Theme.accent }
                        Rectangle { x: parent.width - 30; y: 8; width: 28; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                    }
                    Item {
                        visible: opt.modelData.id === "full"
                        anchors.fill: parent
                        Rectangle { x: 0; y: 4; width: parent.width; height: 22; radius: 3; color: Theme.island; border.width: 1; border.color: Theme.border }
                        Rectangle { x: 6; y: 11; width: 8; height: 8; radius: 4; color: Theme.foreground }
                        Rectangle { x: 20; y: 13; width: 20; height: 4; radius: 2; color: Theme.muted }
                        Rectangle { x: parent.width / 2 - 12; y: 11; width: 24; height: 8; radius: 4; color: Theme.accent }
                        Rectangle { x: parent.width - 36; y: 13; width: 30; height: 4; radius: 2; color: Theme.muted }
                    }
                    Item {
                        visible: opt.modelData.id === "capsules"
                        anchors.fill: parent
                        Rectangle { x: 0; y: 8; width: 12; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                        Rectangle { x: 15; y: 8; width: 22; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                        Rectangle { x: 40; y: 8; width: 18; height: 14; radius: 7; color: Theme.accent }
                        Rectangle { x: parent.width / 2 - 2; y: 8; width: 22; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                        Rectangle { x: parent.width - 40; y: 8; width: 40; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                    }
                    Item {
                        visible: opt.modelData.id === "floating"
                        anchors.fill: parent
                        Rectangle { x: 4; y: 8; width: 22; height: 4; radius: 2; color: Theme.muted }
                        Rectangle { x: parent.width / 2 - 14; y: 4; width: 28; height: 12; radius: 6; color: Theme.island; border.width: 1; border.color: Theme.border }
                        Rectangle { x: parent.width - 52; y: 4; width: 50; height: 12; radius: 6; color: Theme.island; border.width: 1; border.color: Theme.border }
                        Rectangle { x: parent.width / 2 - 26; y: 24; width: 52; height: 14; radius: 7; color: Theme.island; border.width: 1; border.color: Theme.border }
                        Repeater {
                            model: 4
                            Rectangle { required property int index; x: parent.width / 2 - 20 + index * 11; y: 28; width: 6; height: 6; radius: 3; color: index === 1 ? Theme.accent : Theme.foreground }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 58
                    text: opt.modelData.name.toLowerCase()
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: opt.chosen
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 75
                    width: parent.width - 20
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: opt.modelData.hint
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
                Rectangle {   // dot: version in use
                    visible: opt.current
                    x: parent.width - 16; y: 8
                    width: 6; height: 6; radius: 3
                    color: Theme.accent
                }

                MouseArea {
                    id: optMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.go(opt.index); keys.forceActiveFocus() }
                }
            }
        }
    }

    Text {
        x: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        text: (Style.current === "dash" || Style.current === "classic") ? "← →  browse   ·   Esc  cancel" : "Versions: Classic (Mod+Alt+2) and Dashboard (Mod+Alt+3)"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        text: "Enter to apply"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
}
