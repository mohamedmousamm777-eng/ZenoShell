import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.services

// Ten pills (31 Hz ... 16 kHz) with a smooth line joining their tops.
// Drag a pill up or down: the line follows. Behind each pill, a faint bar shows the live sound (cava).
Item {
    id: root

    property color track: Theme.island
    property bool counted: false

    readonly property real padX: 14
    readonly property real valueH: 14
    readonly property real labelH: 14
    readonly property real trackH: Math.max(40, height - valueH - labelH - 8)
    readonly property real slot: (width - padX * 2) / 10
    readonly property real pillW: Math.min(16, slot - 6)

    // Same use counter as the spectrum of the music card: cava runs only while a view needs it
    onVisibleChanged: {
        if (visible && !counted) { Cava.users++; counted = true }
        else if (!visible && counted) { Cava.users--; counted = false }
    }
    Component.onDestruction: if (counted) Cava.users--

    function fillH(db) { return Math.max(root.pillW, root.trackH * (db + AudioFx.range) / (AudioFx.range * 2)) }
    function topY(db) { return root.valueH + root.trackH - fillH(db) }
    function fmt(v) { return (v > 0 ? "+" : "") + (Math.round(v * 10) % 10 === 0 ? Math.round(v) : v.toFixed(1)) }

    // Smooth line through the tops of the pills (Catmull-Rom turned into Bezier curves)
    function buildPath() {
        const g = AudioFx.gains
        const pts = []
        for (let i = 0; i < 10; i++) pts.push([root.padX + (i + 0.5) * root.slot, topY(g[i])])
        let d = "M" + pts[0][0].toFixed(1) + " " + pts[0][1].toFixed(1)
        for (let i = 0; i < 9; i++) {
            const p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2
            const c1x = p1[0] + (p2[0] - p0[0]) / 6, c1y = p1[1] + (p2[1] - p0[1]) / 6
            const c2x = p2[0] - (p3[0] - p1[0]) / 6, c2y = p2[1] - (p3[1] - p1[1]) / 6
            d += " C" + c1x.toFixed(1) + " " + c1y.toFixed(1) + " " + c2x.toFixed(1) + " " + c2y.toFixed(1)
                 + " " + p2[0].toFixed(1) + " " + p2[1].toFixed(1)
        }
        return d
    }
    readonly property string curvePath: buildPath()

    // The whole drawing is dimmed while the equalizer is off, but stays usable (touching it turns the equalizer on)
    Item {
        anchors.fill: parent
        opacity: AudioFx.enabled ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Repeater {
            model: 10

            delegate: Item {
                id: col

                required property int index
                readonly property real db: AudioFx.gains[index]

                x: root.padX + index * root.slot
                width: root.slot
                height: root.height

                Text {
                    y: 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.fmt(col.db)
                    color: col.db !== 0 ? Theme.foreground : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }

                Rectangle {
                    id: tr
                    x: (col.width - root.pillW) / 2
                    y: root.valueH
                    width: root.pillW
                    height: root.trackH
                    radius: width / 2
                    color: root.track

                    // Live sound
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * (Cava.levels[col.index] || 0)
                        radius: width / 2
                        color: Theme.accent
                        opacity: 0.16
                        visible: Cava.available && Media.playing
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }

                    // Value
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: root.fillH(col.db)
                        radius: width / 2
                        color: Theme.accent
                    }

                    // 0 dB
                    Rectangle {
                        y: parent.height / 2
                        width: parent.width
                        height: 1
                        color: Theme.island
                        opacity: 0.55
                    }
                }

                Text {
                    y: root.height - root.labelH
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: AudioFx.freqLabels[col.index]
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }

                MouseArea {
                    y: root.valueH - 4
                    width: parent.width
                    height: root.trackH + 8
                    cursorShape: Qt.PointingHandCursor

                    function setFrom(my) {
                        const frac = 1 - (my - 4) / root.trackH
                        AudioFx.setBand(col.index, (Math.max(0, Math.min(1, frac)) * 2 - 1) * AudioFx.range)
                    }

                    onPressed: mouse => {
                        if (!AudioFx.enabled) AudioFx.setEnabled(true)
                        setFrom(mouse.y)
                    }
                    onPositionChanged: mouse => { if (pressed) setFrom(mouse.y) }
                    onDoubleClicked: AudioFx.setBand(col.index, 0)
                }
            }
        }

        // The line and its dots
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.foreground
                strokeWidth: 2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: root.curvePath }
            }
        }

        Repeater {
            model: 10

            delegate: Rectangle {
                required property int index

                x: root.padX + (index + 0.5) * root.slot - width / 2
                y: root.topY(AudioFx.gains[index]) - height / 2
                width: 9; height: 9
                radius: 4.5
                color: Theme.island
                border.width: 2
                border.color: Theme.foreground
            }
        }
    }
}
