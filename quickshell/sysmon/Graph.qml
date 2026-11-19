import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.services

// Line chart of the last 2 minutes. Several series share one scale; the first one gets the soft fill.
// `rev` changes every time the readings change (SysStats.histRev), that is when it redraws.
Item {
    id: root

    property var series: []              // [[numbers], ...]
    property var colors: []
    property real maxV: 100
    property real minV: 0
    property int rev: 0

    readonly property int n: SysStats.histLen

    function pts(a) {
        const w = width, h = height
        const span = Math.max(0.0001, maxV - minV)
        let d = ""
        const off = n - a.length                        // fewer readings than the window: they start from the right
        for (let i = 0; i < a.length; i++) {
            const x = ((i + off) / (n - 1)) * w
            const y = h - 3 - Math.max(0, Math.min(1, (a[i] - minV) / span)) * (h - 6)
            d += (i === 0 ? "M" : " L") + x.toFixed(1) + " " + y.toFixed(1)
        }
        return d
    }

    // Gridlines: top, middle, bottom
    Repeater {
        model: 3
        Rectangle {
            required property int index
            width: root.width
            height: 1
            y: 3 + index * (root.height - 6) / 2
            color: Theme.foreground
            opacity: 0.08
        }
    }

    Repeater {
        model: root.series.length

        delegate: Shape {
            id: sh

            required property int index
            readonly property string d: { root.rev; return root.pts(root.series[index] || []) }
            readonly property color tone: root.colors[index] || Theme.accent

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // fill under the first series
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: root.height
                    GradientStop { position: 0; color: Qt.rgba(sh.tone.r, sh.tone.g, sh.tone.b, 0.30) }
                    GradientStop { position: 1; color: Qt.rgba(sh.tone.r, sh.tone.g, sh.tone.b, 0.0) }
                }
                PathSvg { path: sh.d === "" || sh.index !== 0 ? "M0 0" : sh.d + " L" + root.width + " " + root.height + " L" + ((root.n - (root.series[0] || []).length) / (root.n - 1) * root.width).toFixed(1) + " " + root.height + " Z" }
            }

            ShapePath {
                strokeColor: sh.tone
                strokeWidth: 1.8
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathSvg { path: sh.d === "" ? "M0 0" : sh.d }
            }
        }
    }
}
