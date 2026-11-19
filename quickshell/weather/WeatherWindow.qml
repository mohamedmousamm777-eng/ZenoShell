import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.settings
import "wx.js" as W

// The weather panel: a card in the middle of the screen (Alt+Shift+M or `qs ipc call weather toggle`).
// Esc or a click outside closes it. Before the user allows internet access it only shows the permission screen.
Scope {
    id: root

    IpcHandler {
        target: "weather"
        function toggle(): void { Weather.togglePanel() }
        function open(): void { Weather.openPanel() }
        function close(): void { Weather.closePanel() }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            readonly property bool here: Weather.open
                && (Weather.screenName === "" || Weather.screenName === modelData.name)

            visible: here || card.opacity > 0
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell-weather"
            WlrLayershell.keyboardFocus: win.here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onHereChanged: if (here) keys.forceActiveFocus()

            MouseArea {
                anchors.fill: parent
                onClicked: Weather.closePanel()
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: {
                    if (card.pickerOpen && Weather.hasPlace) card.pickerOpen = false
                    else Weather.closePanel()
                }
            }

            Rectangle {
                id: card

                readonly property int lx: 36
                readonly property int lw: 400
                readonly property int rx: lx + lw + 28
                readonly property int rw: width - rx - 36

                property bool pickerOpen: false
                readonly property var wx: Weather.wx
                readonly property bool asking: !Weather.consent
                readonly property bool picking: Weather.consent
                    && (pickerOpen || (!Weather.hasPlace && !(Weather.autoLocation && Weather.loading)))

                // Minute of the day at the chosen place (from the forecast time + the time passed since)
                property real nowMin: 0
                function updateNow() {
                    nowMin = wx ? wx.placeNow + (Date.now() - Weather.fetchedAt) / 60000 : 0
                }
                Connections { target: Weather; function onWxChanged() { card.updateNow() } }
                Timer { interval: 60000; repeat: true; running: win.here; onTriggered: card.updateNow() }

                anchors.centerIn: parent
                width: Math.min(920, win.width - 60)
                height: Math.min(520, win.height - 60)
                radius: 26
                color: Theme.island
                border.width: 1
                border.color: Theme.border
                clip: true
                opacity: win.here ? 1 : 0
                scale: win.here ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                onPickerOpenChanged: if (pickerOpen) picker.focusField()
                Connections { target: win; function onHereChanged() { if (!win.here) card.pickerOpen = false } }

                MouseArea { anchors.fill: parent }   // clicks inside do not close the panel

                // ======================= LEFT =======================
                Item {
                    id: leftCol
                    x: card.lx; y: 0
                    width: card.lw; height: card.height
                    visible: card.wx !== null

                    // Current weather
                    WxIcon {
                        x: 0; y: 40
                        width: 56; height: 56
                        kind: card.wx ? (card.wx.isDay === false && W.kindOf(card.wx.code) === "clear" ? "moon" : W.kindOf(card.wx.code)) : "cloud"
                        color: Theme.accent
                        lineW: 1.4
                    }

                    Text {
                        x: 74; y: 26
                        width: card.lw - 74 - 44
                        text: Weather.place
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.pickerOpen = true
                        }
                    }

                    Text {
                        id: bigTemp
                        x: 72; y: 40
                        text: card.wx ? Math.round(card.wx.temp) + "°" : ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 54
                    }

                    Column {
                        x: bigTemp.x + bigTemp.width + 14
                        y: 66
                        spacing: 2
                        Text {
                            text: card.wx ? W.condText(card.wx.code, Weather.lang) : ""
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                        Text {
                            text: card.wx && card.wx.days.length ? "↑" + Math.round(card.wx.days[0].hi) + "°   ↓" + Math.round(card.wx.days[0].lo) + "°" : ""
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    // Refresh
                    Rectangle {
                        x: card.lw - 30; y: 30
                        width: 30; height: 30; radius: 15
                        color: rm.containsMouse ? Theme.islandHover : "transparent"

                        WxIcon {
                            id: refreshIcon
                            anchors.centerIn: parent
                            width: 18; height: 18
                            kind: "refresh"
                            color: Theme.muted
                            RotationAnimator on rotation {
                                running: Weather.loading
                                from: 0; to: 360; duration: 900
                                loops: Animation.Infinite
                            }
                        }
                        MouseArea {
                            id: rm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Weather.refresh()
                        }
                    }

                    // Next days
                    Column {
                        id: daysCol
                        y: 128
                        width: card.lw
                        spacing: 4

                        readonly property real gmin: {
                            if (!card.wx) return 0
                            let v = 1e9
                            for (let i = 0; i < card.wx.days.length; i++) v = Math.min(v, card.wx.days[i].lo)
                            return v
                        }
                        readonly property real gmax: {
                            if (!card.wx) return 1
                            let v = -1e9
                            for (let i = 0; i < card.wx.days.length; i++) v = Math.max(v, card.wx.days[i].hi)
                            return Math.max(v, gmin + 1)
                        }

                        Repeater {
                            model: card.wx ? card.wx.days : []

                            delegate: Item {
                                required property var modelData
                                required property int index
                                width: card.lw
                                height: 30

                                Text {
                                    x: 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 56
                                    text: W.dayLabel(modelData.date, Weather.lang, index)
                                    color: index === 0 ? Theme.foreground : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: index === 0
                                }
                                WxIcon {
                                    x: 56
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20; height: 20
                                    kind: W.kindOf(modelData.code)
                                    color: Theme.accent
                                    lineW: 1.4
                                }
                                Text {
                                    x: 84
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 36
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(modelData.lo) + "°"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                                Rectangle {
                                    id: track
                                    x: 130
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: card.lw - 130 - 44
                                    height: 6; radius: 3
                                    color: Theme.border
                                    opacity: 0.6
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: track.x + (modelData.lo - daysCol.gmin) / (daysCol.gmax - daysCol.gmin) * track.width
                                    width: Math.max(8, (modelData.hi - modelData.lo) / (daysCol.gmax - daysCol.gmin) * track.width)
                                    height: 6; radius: 3
                                    color: Theme.accent
                                }
                                Text {
                                    x: card.lw - 40
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40
                                    horizontalAlignment: Text.AlignRight
                                    text: Math.round(modelData.hi) + "°"
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }

                    // Air quality
                    readonly property var aq: W.aqiInfo(Weather.aqi)

                    Text {
                        x: 0; y: 322
                        text: Weather.tr("air")
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                    Text {
                        y: 322
                        anchors.right: parent.right
                        text: leftCol.aq.key !== "" ? Weather.tr(leftCol.aq.key) + "  " + Math.round(Weather.aqi) : "–"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Rectangle {
                        id: aqBar
                        x: 0; y: 346
                        width: card.lw; height: 7; radius: 4
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#2fbf8a" }
                            GradientStop { position: 0.35; color: "#9acd32" }
                            GradientStop { position: 0.65; color: "#f6c427" }
                            GradientStop { position: 1.0; color: "#e5484d" }
                        }
                        opacity: leftCol.aq.key !== "" ? 1 : 0.35
                    }
                    Rectangle {
                        visible: leftCol.aq.key !== ""
                        x: aqBar.width * leftCol.aq.t - 5
                        y: 346 + 3.5 - 5
                        width: 10; height: 10; radius: 5
                        color: Theme.island
                        border.width: 2
                        border.color: Theme.foreground
                    }

                    // Sun
                    Row {
                        x: 0; y: 384
                        spacing: 5
                        WxIcon { width: 16; height: 16; kind: "sunrise"; color: Theme.muted; lineW: 1.5 }
                        Text {
                            text: Weather.tr("sunrise") + " " + (card.wx ? card.wx.sunrise : "")
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                    Row {
                        y: 384
                        anchors.right: parent.right
                        spacing: 5
                        Text {
                            text: Weather.tr("sunset") + " " + (card.wx ? card.wx.sunset : "")
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                        WxIcon { width: 16; height: 16; kind: "sunset"; color: Theme.muted; lineW: 1.5 }
                    }

                    readonly property real sunP: card.wx && card.wx.sunriseMin >= 0 && card.wx.sunsetMin > card.wx.sunriseMin
                        ? Math.max(0, Math.min(1, (card.nowMin - card.wx.sunriseMin) / (card.wx.sunsetMin - card.wx.sunriseMin))) : 0

                    Rectangle {
                        id: sunTrack
                        x: 0; y: 412
                        width: card.lw; height: 7; radius: 4
                        color: Theme.border
                        opacity: 0.6
                    }
                    Rectangle {
                        x: 0; y: 412
                        width: card.lw * leftCol.sunP; height: 7; radius: 4
                        color: Theme.accent
                    }
                    Rectangle {
                        x: Math.max(0, Math.min(card.lw - 14, card.lw * leftCol.sunP - 7))
                        y: 412 + 3.5 - 7
                        width: 14; height: 14; radius: 7
                        color: Theme.island
                        border.width: 3
                        border.color: Theme.accent
                    }

                    // Error while data is shown
                    Row {
                        visible: Weather.error !== ""
                        x: 0; y: 450
                        spacing: 8
                        Text {
                            text: Weather.error === "offline" ? Weather.tr("offline") : Weather.error
                            color: Theme.danger
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                        Text {
                            text: Weather.tr("retry")
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.underline: true
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Weather.refresh()
                            }
                        }
                    }
                }

                // No data yet
                Column {
                    visible: card.wx === null && !card.asking && !card.picking
                    x: card.lx; y: card.height / 2 - 30
                    width: card.lw
                    spacing: 10
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Weather.error !== "" ? (Weather.error === "offline" ? Weather.tr("offline") : Weather.error) : Weather.tr("loading")
                        color: Weather.error !== "" ? Theme.danger : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                    Text {
                        visible: Weather.error !== ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.tr("retry")
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.underline: true
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Weather.hasPlace ? Weather.refresh() : Weather.locate()
                        }
                    }
                }

                // ======================= RIGHT =======================
                // Created only while the panel is shown (tiles and canvases cost memory)
                Loader {
                    x: card.rx; y: 30
                    width: card.rw; height: 270
                    active: win.here || card.opacity > 0
                    sourceComponent: MapView {}
                }

                Grid {
                    x: card.rx; y: 322
                    columns: 3
                    columnSpacing: 0
                    rowSpacing: 8
                    visible: card.wx !== null

                    readonly property bool imp: Weather.units === "imperial"
                    readonly property var items: !card.wx ? [] : [
                        { icon: "m-uv",    label: Weather.tr("uv"),         value: String(Math.round(card.wx.uv)), unit: "" },
                        { icon: "l-temp",  label: Weather.tr("feels"),      value: String(Math.round(card.wx.feels)), unit: imp ? "°F" : "°C" },
                        { icon: "m-hum",   label: Weather.tr("humidity"),   value: String(Math.round(card.wx.hum)), unit: "%" },
                        { icon: "m-wind",  label: Weather.tr("wind"),       value: String(Math.round(card.wx.wind)), unit: imp ? "mph" : "km/h" },
                        { icon: "l-press", label: Weather.tr("pressure"),   value: String(Math.round(card.wx.press)), unit: "hPa" },
                        { icon: "m-vis",   label: Weather.tr("visibility"), value: card.wx.vis < 0 ? "–" : (imp ? (card.wx.vis / 1609.34).toFixed(1) : String(Math.round(card.wx.vis / 1000))),
                          unit: imp ? "mi" : "km" }
                    ]

                    Repeater {
                        model: parent.items

                        delegate: Item {
                            required property var modelData
                            width: card.rw / 3
                            height: 74

                            WxIcon {
                                x: 0; y: 2
                                width: 16; height: 16
                                kind: modelData.icon
                                color: Theme.muted
                                lineW: 1.5
                            }
                            Text {
                                x: 24; y: 2
                                text: modelData.label
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                            Row {
                                x: 2; y: 30
                                spacing: 5
                                Text {
                                    id: val
                                    text: modelData.value
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 24
                                }
                                Text {
                                    anchors.baseline: val.baseline
                                    text: modelData.unit
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }

                // ======================= Place picker =======================
                Rectangle {
                    anchors.fill: parent
                    visible: card.picking
                    color: Theme.island
                    radius: card.radius

                    MouseArea { anchors.fill: parent }

                    Column {
                        anchors.centerIn: parent
                        width: 380
                        spacing: 14

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Weather.tr("needsPlace")
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            font.bold: true
                        }

                        CitySearch {
                            id: picker
                            width: parent.width
                            autoFocus: true
                            onChosen: card.pickerOpen = false
                            onEscaped: if (Weather.hasPlace) card.pickerOpen = false
                        }

                        Text {
                            visible: Weather.error === "location"
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Weather.lang === "it" ? "Non riesco a trovare la tua posizione: cerca una città." : "Could not find your location: search for a city."
                            color: Theme.danger
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            SButton {
                                label: Weather.tr("myLocation")
                                base: Theme.surfaceSoft
                                onClicked: { card.pickerOpen = false; Weather.set("autoLocation", true); Weather.locate() }
                            }
                            SButton {
                                visible: Weather.hasPlace
                                label: "Esc"
                                base: Theme.surfaceSoft
                                onClicked: card.pickerOpen = false
                            }
                        }
                    }
                }

                // ======================= Permission =======================
                Rectangle {
                    anchors.fill: parent
                    visible: card.asking
                    color: Theme.island
                    radius: card.radius

                    MouseArea { anchors.fill: parent }

                    Column {
                        anchors.centerIn: parent
                        width: Math.min(560, card.width - 80)
                        spacing: 14

                        WxIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 44; height: 44
                            kind: "partly"
                            color: Theme.accent
                            lineW: 1.4
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: Weather.tr("askTitle")
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                            font.bold: true
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: Weather.tr("askText")
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                        Rectangle {
                            width: parent.width
                            height: asks.implicitHeight + 24
                            radius: 16
                            color: Theme.surfaceSoft
                            Column {
                                id: asks
                                x: 16; y: 12
                                width: parent.width - 32
                                spacing: 6
                                Repeater {
                                    model: ["askWeather", "askMap", "askIp"]
                                    delegate: Text {
                                        required property string modelData
                                        width: asks.width
                                        wrapMode: Text.WordWrap
                                        text: "•  " + Weather.tr(modelData)
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8
                            SButton {
                                accent: true
                                label: Weather.tr("allowAuto")
                                onClicked: { Weather.set("autoLocation", true); Weather.setConsent(true) }
                            }
                            SButton {
                                label: Weather.tr("allowCity")
                                base: Theme.surfaceSoft
                                onClicked: { Weather.set("autoLocation", false); Weather.setConsent(true) }
                            }
                            SButton {
                                label: Weather.tr("notNow")
                                base: Theme.surfaceSoft
                                onClicked: Weather.closePanel()
                            }
                        }
                    }
                }
            }
        }
    }
}
