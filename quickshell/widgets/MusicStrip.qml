import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme
import qs.services

// Slim music strip: blurred cover as background, round cover, title, artist and the three controls.
// Sits above the equalizer in the side panel (Vertical style).
Item {
    id: root

    implicitWidth: 320
    implicitHeight: 56

    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: Theme.surfaceSoft

        Image {
            id: blurSrc
            anchors.fill: parent
            source: Media.artUrl
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(96, 96)
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: blurSrc
            visible: Media.active
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.3
        }

        Rectangle { anchors.fill: parent; color: Theme.scrim; visible: Media.active }
    }

    ClippingRectangle {
        x: 8; y: 8
        width: 40; height: 40
        radius: 20
        color: Theme.surfaceSoft
        visible: Media.active

        Image {
            anchors.fill: parent
            source: Media.artUrl
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(128, 128)
        }
    }

    Text {
        visible: !Media.active
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        text: "Nothing playing"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    Column {
        visible: Media.active
        x: 58
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - 58 - 110
        spacing: 1

        Text {
            width: parent.width
            text: Media.title || "No title"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: Media.artist
            color: Theme.foreground
            opacity: 0.7
            font.family: Theme.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    Row {
        visible: Media.active
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        MediaButton { kind: "prev"; enabled: Media.canPrevious; onClicked: Media.previous() }
        MediaButton { kind: Media.playing ? "pause" : "play"; highlighted: true; enabled: Media.canToggle; onClicked: Media.toggle() }
        MediaButton { kind: "next"; enabled: Media.canNext; onClicked: Media.next() }
    }
}
