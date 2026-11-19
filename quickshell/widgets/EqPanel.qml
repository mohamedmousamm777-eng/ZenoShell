import QtQuick
import qs.theme
import qs.services

// The Audio Center: equalizer with switch, preset name and the controls.
//   kind  "knobs" -> Bass / Treble / Balance knobs, the ten bands behind "Fine tune" (Island and Classic styles)
//   kind  "curve" -> ten pills with the line joining them, and the presets (Dashboard and Vertical styles)
//   style "card"  -> its own background, border and rounded corners (hangs under the music island)
//         "inner" -> a rounded card inside a side panel (Vertical)
//         "wide"  -> the card of the Dashboard
//         "flat"  -> no background of its own: it lives inside the music island, which grows to hold it
Item {
    id: root

    property string kind: "curve"
    property string style: "card"
    property bool fine: false               // knobs panel showing the ten bands

    readonly property bool showCurve: kind === "curve" || fine
    readonly property color onBox: style === "flat" ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
                                   : (style === "card" ? Theme.surfaceSoft : Theme.island)

    width: style === "wide" ? 644 : 340
    height: style === "wide" ? 308 : (style === "inner" ? 350 : (style === "flat" ? 332 : 330))

    function reset() { fine = false }

    Rectangle {
        id: box

        x: root.style === "inner" ? 10 : 0
        y: root.style === "inner" ? 10 : 0
        width: root.width - x * 2
        height: root.height - y * 2
        radius: 22
        color: root.style === "flat" ? "transparent" : (root.style === "card" ? Theme.island : Theme.surfaceSoft)
        border.width: root.style === "card" ? 1 : 0
        border.color: Theme.border

        // ---------- Header ----------
        Item {
            id: head
            width: parent.width
            height: 42

            Rectangle {
                visible: root.style === "flat"
                x: 14; y: 0
                width: parent.width - 28
                height: 1
                color: Theme.foreground
                opacity: 0.18
            }

            Item {
                x: 14; y: 0
                width: titleRow.implicitWidth
                height: parent.height

                Row {
                    id: titleRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        visible: root.fine && root.kind === "knobs"
                        anchors.verticalCenter: parent.verticalCenter
                        text: "‹"
                        color: Theme.foreground
                        font.pixelSize: 18
                    }

                    Glyph {
                        visible: !(root.fine && root.kind === "knobs")
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "eq"
                        size: 15
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.fine && root.kind === "knobs" ? "Fine tune" : "Equalizer"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.fine && root.kind === "knobs"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.fine = false
                }
            }

            Toggle {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                checked: AudioFx.enabled
                onToggled: AudioFx.toggle()
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14 + 40 + 10
                anchors.verticalCenter: parent.verticalCenter
                text: AudioFx.error !== "" ? AudioFx.error
                      : (AudioFx.enabled && !AudioFx.active ? "Starting..." : (AudioFx.preset !== "" ? AudioFx.preset : "Custom"))
                color: AudioFx.error !== "" ? Theme.danger : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 10
                elide: Text.ElideLeft
                width: Math.min(implicitWidth, box.width - 170)
            }
        }

        // ---------- Content ----------
        // Only the view on screen exists: while a knob is dragged nothing else is recalculated
        Loader {
            active: !root.showCurve
            y: head.height
            width: box.width
            height: box.height - head.height

            sourceComponent: EqKnobs {
                width: box.width
                height: box.height - head.height
                track: root.onBox
                onFineRequested: root.fine = true
            }
        }

        Loader {
            id: curveBox
            active: root.showCurve
            y: head.height
            width: box.width
            height: box.height - head.height

            sourceComponent: Item {
                EqCurve {
                    y: 0
                    width: box.width
                    height: curveBox.height - presets.height - 22
                    track: root.onBox
                }

                EqPresets {
                    id: presets
                    x: 14
                    y: curveBox.height - height - 12
                    width: box.width - 28
                    base: root.onBox
                }
            }
        }
    }
}
