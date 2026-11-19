import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.services

// Bass, Treble and Balance as three knobs, the presets one by one, and a way into the ten bands.
// Drag a knob up or down (or use the wheel); double click puts it back in the middle.
Item {
    id: root

    property color track: Theme.surfaceSoft

    signal fineRequested()

    component Dial: Item {
        id: d

        property string label: ""
        property string valueText: ""
        property real frac: 0.5                 // 0..1
        property real local: 0.5                // value while dragging: the knob never waits for the engine
        readonly property real shown: dm.pressed ? local : frac
        signal moved(real f)

        width: 84
        height: 100

        Shape {
            width: 84; height: 84
            preferredRendererType: Shape.CurveRenderer     // smooth edges without an extra multisampled layer

            ShapePath {
                strokeColor: root.track
                strokeWidth: 7
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 42; centerY: 42; radiusX: 35; radiusY: 35; startAngle: 135; sweepAngle: 270 }
            }

            ShapePath {
                strokeColor: Theme.accent
                strokeWidth: 7
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 42; centerY: 42; radiusX: 35; radiusY: 35; startAngle: 135; sweepAngle: Math.max(0.01, 270 * d.shown) }
            }
        }

        Rectangle {
            readonly property real a: (135 + 270 * d.shown) * Math.PI / 180
            x: 42 + 35 * Math.cos(a) - width / 2
            y: 42 + 35 * Math.sin(a) - height / 2
            width: 9; height: 9
            radius: 4.5
            color: Theme.foreground
        }

        Text {
            x: 0; y: 0
            width: 84; height: 84
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: d.valueText
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.bold: true
        }

        Text {
            y: 84
            width: 84
            horizontalAlignment: Text.AlignHCenter
            text: d.label.toUpperCase()
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.letterSpacing: 1
        }

        MouseArea {
            id: dm
            width: 84; height: 84
            cursorShape: Qt.PointingHandCursor

            property bool dirty: false

            // The knob follows the pointer around the circle: click where you want it, then drag.
            function follow(mx, my) {
                const dx = mx - 42, dy = my - 42
                if (dx * dx + dy * dy < 100) return                 // too close to the centre to know the angle
                let deg = Math.atan2(dy, dx) * 180 / Math.PI
                if (deg < 0) deg += 360
                let rel = deg - 135
                if (rel < 0) rel += 360
                if (rel > 270) rel = (rel - 270 < 360 - rel) ? 270 : 0      // the gap at the bottom: nearest end
                d.local = rel / 270
                dirty = true
            }

            // Sent to the equalizer 30 times a second at most; the arc itself moves on every event
            Timer {
                running: dm.pressed
                interval: 33
                repeat: true
                onTriggered: if (dm.dirty) { dm.dirty = false; d.moved(d.local) }
            }

            onPressed: mouse => {
                d.local = d.frac
                if (!AudioFx.enabled) AudioFx.setEnabled(true)
                follow(mouse.x, mouse.y)
            }
            onPositionChanged: mouse => { if (pressed) follow(mouse.x, mouse.y) }
            onReleased: if (dirty) { dirty = false; d.moved(d.local) }
            onCanceled: if (dirty) { dirty = false; d.moved(d.local) }
            onDoubleClicked: d.moved(0.5)
            onWheel: wheel => d.moved(Math.max(0, Math.min(1, d.frac + (wheel.angleDelta.y > 0 ? 1 : -1) / 24)))
        }
    }

    function sign(v) { return (v > 0.4 ? "+" : "") + Math.round(v) }

    // ---------- Knobs ----------
    Row {
        y: 6
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: (root.width - 20 - 84 * 3) / 2

        Dial {
            label: "Bass"
            valueText: root.sign(AudioFx.bass)
            frac: (AudioFx.bass + AudioFx.range) / (AudioFx.range * 2)
            onMoved: f => AudioFx.setBass(f * AudioFx.range * 2 - AudioFx.range)
        }

        Dial {
            label: "Treble"
            valueText: root.sign(AudioFx.treble)
            frac: (AudioFx.treble + AudioFx.range) / (AudioFx.range * 2)
            onMoved: f => AudioFx.setTreble(f * AudioFx.range * 2 - AudioFx.range)
        }

        Dial {
            label: "Balance"
            valueText: AudioFx.balance === 0 ? "C" : (AudioFx.balance < 0 ? "L" : "R") + Math.round(Math.abs(AudioFx.balance) * 100)
            frac: (AudioFx.balance + 1) / 2
            onMoved: f => AudioFx.setBalance(Math.abs(f - 0.5) < 0.03 ? 0 : f * 2 - 1)
        }
    }

    // ---------- Presets, one by one ----------
    Item {
        y: 112
        width: root.width
        height: 34

        Rectangle {
            x: 28; y: 4
            width: 26; height: 26
            radius: 13
            color: pm1.containsMouse ? Theme.islandHover : root.track

            Text { anchors.centerIn: parent; text: "‹"; color: Theme.foreground; font.pixelSize: 16 }
            MouseArea { id: pm1; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: AudioFx.nextPreset(-1) }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: AudioFx.preset !== "" ? AudioFx.preset : "Custom"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: AudioFx.isMine(AudioFx.preset) ? "your preset · right click ×" : "preset"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 9

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: if (AudioFx.isMine(AudioFx.preset)) AudioFx.deleteUserPreset(AudioFx.preset)
                }
            }
        }

        Rectangle {
            x: root.width - 28 - width; y: 4
            width: 26; height: 26
            radius: 13
            color: pm2.containsMouse ? Theme.islandHover : root.track

            Text { anchors.centerIn: parent; text: "›"; color: Theme.foreground; font.pixelSize: 16 }
            MouseArea { id: pm2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: AudioFx.nextPreset(1) }
        }
    }

    // ---------- The ten bands ----------
    Rectangle {
        x: 16; y: 164
        width: root.width - 32
        height: 1
        color: Theme.border
        opacity: 0.6
    }

    Item {
        x: 16; y: 174
        width: root.width - 32
        height: 52

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                text: "Fine tune  ›"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                text: "10 bands, 31 Hz to 16 kHz"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: 10

                delegate: Rectangle {
                    required property int index
                    anchors.bottom: parent.bottom
                    width: 9
                    height: Math.max(5, 34 * (AudioFx.gains[index] + AudioFx.range) / (AudioFx.range * 2))
                    radius: 4.5
                    color: Theme.accent
                    opacity: AudioFx.enabled ? 0.9 : 0.4
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.fineRequested()
        }
    }

    // ---------- Keep this curve ----------
    Rectangle {
        x: 16; y: root.height - 34
        width: sv.implicitWidth + 24
        height: 24
        radius: 12
        color: svm.containsMouse ? Theme.islandHover : root.track

        Text {
            id: sv
            anchors.centerIn: parent
            text: "+ Save as preset"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        MouseArea { id: svm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: AudioFx.saveCurrent() }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: root.height - 34
        height: 24
        verticalAlignment: Text.AlignVCenter
        text: AudioFx.headroom ? "Headroom on" : "Headroom off"
        color: hm.containsMouse ? Theme.foreground : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10

        MouseArea { id: hm; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: AudioFx.setHeadroom(!AudioFx.headroom) }
    }
}
