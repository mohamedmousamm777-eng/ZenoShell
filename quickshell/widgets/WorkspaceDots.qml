import QtQuick
import qs.theme
import qs.services

// Workspaces of the classic bar. `look`:
//   bar       dots, the active one stretches (original)
//   full      kanji numbers, the active one is a round marker (the notch behind is drawn by the bar)
//   capsules  small dots, the active one is a ring
//   floating  tall pills
Rectangle {
    id: root

    property string screenName: ""
    property string look: "bar"

    readonly property var dots: Compositor.dotsFor(screenName)
    readonly property int activeId: Compositor.activeIdFor(screenName)
    readonly property int activeIndex: {
        for (let i = 0; i < dots.length; i++) if (dots[i].id === activeId) return i
        return -1
    }
    readonly property bool tall: look === "floating"
    readonly property bool kanji: look === "full"
    readonly property bool rings: look === "capsules"
    readonly property var nums: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    readonly property color dark: Qt.rgba(0.03, 0.03, 0.04, 0.96)
    readonly property color lit: Theme.mix(Theme.accent, "#ffffff", 0.35)

    readonly property int cell: kanji ? 28 : (rings ? 14 : 10)
    readonly property int gap: kanji ? 6 : (rings ? 16 : 7)

    height: Theme.islandHeight
    width: row.implicitWidth + (kanji ? 20 : (rings ? 40 : 26))
    radius: height / 2
    color: kanji ? "transparent" : (look === "bar" ? Theme.island : dark)
    border.width: (kanji || look !== "bar") ? 0 : 1
    border.color: Theme.border

    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (wheelCool.running) return
            Compositor.focusWorkspaceRelative(event.angleDelta.y > 0 ? -1 : 1)
            wheelCool.start()
        }
    }

    Timer { id: wheelCool; interval: 150 }

    // "full": the trail up to the active workspace
    Rectangle {
        visible: root.kanji && root.activeIndex > 0
        x: row.x - 4
        anchors.verticalCenter: parent.verticalCenter
        height: 26
        radius: 13
        width: 4 + root.activeIndex * (root.cell + root.gap) + root.cell + 4
        color: Qt.rgba(1, 1, 1, 0.12)
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    // "full": marker that slides to the active workspace
    Rectangle {
        visible: root.kanji && root.activeIndex >= 0
        x: row.x + root.activeIndex * (root.cell + root.gap)
        anchors.verticalCenter: parent.verticalCenter
        width: root.cell; height: 26; radius: 13
        color: Theme.accent
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: root.dots

            delegate: Item {
                id: d

                required property var modelData
                required property int index
                readonly property bool active: modelData.id === root.activeId

                width: root.look === "bar" ? (active ? 38 : 10) : root.cell
                height: root.look === "bar" ? 10 : root.height
                anchors.verticalCenter: parent.verticalCenter

                Behavior on width { enabled: root.look === "bar"; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                // bar / floating: pill
                Rectangle {
                    visible: root.look === "bar" || root.tall
                    anchors.centerIn: parent
                    width: root.tall ? 8 : parent.width
                    height: root.tall ? (d.active ? 22 : 18) : 10
                    radius: 4
                    color: d.active ? Theme.accent
                           : (d.modelData.occupied ? (root.tall ? Theme.mix(Theme.island, Theme.accent, 0.55) : Theme.foreground)
                                                   : Theme.mix(Theme.island, Theme.foreground, 0.20))
                    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                // capsules: dot, the active one is a ring with a dot inside
                Rectangle {
                    visible: root.rings
                    anchors.centerIn: parent
                    width: d.active ? 22 : 6
                    height: width; radius: width / 2
                    color: d.active ? root.lit : (d.modelData.occupied ? Theme.foreground : Qt.rgba(1, 1, 1, 0.45))
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8; height: 8; radius: 4
                        color: root.dark
                        opacity: d.active ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                }

                // full: kanji
                Text {
                    visible: root.kanji
                    anchors.centerIn: parent
                    text: root.nums[d.index] || (d.index + 1)
                    font.pixelSize: 13
                    font.bold: d.active
                    color: d.active ? root.dark : (d.modelData.occupied ? Theme.foreground : Theme.muted)
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Compositor.focusWorkspace(d.modelData.id)
                }
            }
        }
    }
}
