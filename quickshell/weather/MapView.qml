import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme
import qs.services
import "wx.js" as W

// A real map: tiles you can drag and zoom, with a colored layer made from the weather data.
ClippingRectangle {
    id: root

    readonly property int ts: 256
    property int zoom: 7
    property real cwx: 0                 // center, in world pixels of this zoom
    property real cwy: 0

    readonly property string style: Weather.mapStyle === "auto" ? (Theme.light ? "light" : "dark") : Weather.mapStyle
    readonly property real ws: W.worldSize(zoom)

    radius: 24
    color: Theme.surfaceSoft
    border.width: 1
    border.color: Theme.border

    // ---------- Center ----------
    function recenter() {
        const z = Weather.hasPlace ? 7 : 3
        zoom = z
        cwx = W.lonToX(Weather.hasPlace ? Weather.lon : 10, z)
        cwy = W.latToY(Weather.hasPlace ? Weather.lat : 30, z)
    }

    function clampCenter() {
        cwx = ((cwx % ws) + ws) % ws
        cwy = Math.max(height / 2, Math.min(ws - height / 2, cwy))
    }

    function setZoom(z) {
        z = Math.max(3, Math.min(11, z))
        if (z === zoom) return
        const k = Math.pow(2, z - zoom)
        cwx *= k
        cwy *= k
        zoom = z
        clampCenter()
    }

    Component.onCompleted: recenter()
    Connections {
        target: Weather
        function onPlacePicked() { root.recenter() }
    }

    // ---------- Tiles ----------
    readonly property int tx0: Math.floor((cwx - width / 2) / ts)
    readonly property int tx1: Math.floor((cwx + width / 2) / ts)
    readonly property int ty0: Math.floor((cwy - height / 2) / ts)
    readonly property int ty1: Math.floor((cwy + height / 2) / ts)
    readonly property int nx: Math.max(1, tx1 - tx0 + 1)
    readonly property int ny: Math.max(1, ty1 - ty0 + 1)

    function tileKey(tx, ty) {
        const n = Math.pow(2, zoom)
        if (ty < 0 || ty >= n) return ""
        return style + "/" + zoom + "/" + (((tx % n) + n) % n) + "/" + ty
    }

    function wantTiles() {
        if (width <= 0 || !Weather.consent) return
        const keys = []
        // The center first, then the rest
        for (let y = ty0; y <= ty1; y++)
            for (let x = tx0; x <= tx1; x++) {
                const k = tileKey(x, y)
                if (k !== "") keys.push(k)
            }
        Weather.requestTiles(keys)
    }

    Timer { id: tileT; interval: 80; onTriggered: root.wantTiles() }
    onTx0Changed: tileT.restart()
    onTx1Changed: tileT.restart()
    onTy0Changed: tileT.restart()
    onTy1Changed: tileT.restart()
    onStyleChanged: tileT.restart()
    Connections {
        target: Weather
        function onConsentChanged() { tileT.restart() }
    }

    Item {
        id: tiles
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 0.16
            colorizationColor: Theme.accent
            saturation: -0.35
        }

        Repeater {
            model: root.width > 0 ? root.nx * root.ny : 0

            delegate: Image {
                required property int index

                readonly property int tx: root.tx0 + index % root.nx
                readonly property int ty: root.ty0 + Math.floor(index / root.nx)
                readonly property string key: root.tileKey(tx, ty)

                x: root.width / 2 + tx * root.ts - root.cwx
                y: root.height / 2 + ty * root.ts - root.cwy
                width: root.ts
                height: root.ts
                sourceSize: Qt.size(root.ts * 2, root.ts * 2)
                asynchronous: true
                cache: true
                fillMode: Image.Stretch
                source: key !== "" && Weather.tileReady[key] ? "file://" + Weather.tileDir + "/" + key + ".png" : ""
            }
        }
    }

    // ---------- Weather layer ----------
    readonly property var rng: W.range(Weather.layer, Weather.grid, Weather.units)
    readonly property real cell: 6

    Timer {
        id: paintT
        interval: 40
        onTriggered: { heat.requestPaint(); arrows.requestPaint() }
    }
    function repaint() { if (!paintT.running) paintT.start() }
    onCwxChanged: repaint()
    onCwyChanged: repaint()
    onZoomChanged: { repaint(); tileT.restart() }
    onWidthChanged: { repaint(); gridT.restart() }
    onHeightChanged: repaint()
    onRngChanged: { repaint(); legend.requestPaint() }
    Connections {
        target: Weather
        function onGridChanged() { root.repaint() }
        function onLayerChanged() { root.repaint(); legend.requestPaint() }
    }
    Connections {
        target: Theme
        function onForegroundChanged() { root.repaint() }
    }

    // Small canvas (one pixel per 6 px of the map), scaled up and smoothed: a soft color wash
    Canvas {
        id: heat
        width: Math.ceil(root.width / root.cell)
        height: Math.ceil(root.height / root.cell)
        scale: root.cell
        transformOrigin: Item.TopLeft
        smooth: true
        visible: Weather.grid !== null

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const g = Weather.grid
            if (!g) return
            const vals = g[({ temp: "temp", wind: "wind", cloud: "cloud", rain: "rain", press: "press" })[Weather.layer]]
            if (!vals) return
            const r = root.rng
            for (let py = 0; py < height; py++) {
                const lat = W.yToLat(root.cwy + (py + 0.5) * root.cell - root.height / 2, root.zoom)
                for (let px = 0; px < width; px++) {
                    let lon = W.xToLon(root.cwx + (px + 0.5) * root.cell - root.width / 2, root.zoom)
                    if (lon > 180) lon -= 360
                    if (lon < -180) lon += 360
                    const v = W.sample(g, vals, lat, lon)
                    if (isNaN(v)) continue
                    const c = W.layerColor(Weather.layer, v, r.lo, r.hi)
                    if (c[3] <= 0.01) continue
                    ctx.fillStyle = "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + c[3] + ")"
                    ctx.fillRect(px, py, 1, 1)
                }
            }
        }
    }

    // Wind direction arrows
    Canvas {
        id: arrows
        anchors.fill: parent
        visible: Weather.layer === "wind" && Weather.grid !== null

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const g = Weather.grid
            if (!g || Weather.layer !== "wind") return
            ctx.strokeStyle = Theme.foreground
            ctx.fillStyle = Theme.foreground
            ctx.lineWidth = 1.6
            ctx.lineCap = "round"
            ctx.globalAlpha = 0.85
            const mx = root.rng.hi
            for (let i = 0; i < g.cols * g.rows; i++) {
                const c = i % g.cols, r = Math.floor(i / g.cols)
                const lat = g.n - (g.n - g.s) * r / (g.rows - 1)
                const lon = g.w + (g.e - g.w) * c / (g.cols - 1)
                let x = root.width / 2 + W.lonToX(lon, root.zoom) - root.cwx
                if (x < -root.ws / 2) x += root.ws
                if (x > root.ws / 2) x -= root.ws
                const y = root.height / 2 + W.latToY(lat, root.zoom) - root.cwy
                if (x < 8 || y < 8 || x > root.width - 8 || y > root.height - 8) continue
                const sp = g.wind[i], dir = g.dir[i]
                if (typeof sp !== "number" || typeof dir !== "number") continue
                const len = 8 + 14 * Math.min(1, sp / mx)
                const a = (dir + 180) * Math.PI / 180        // the wind blows towards dir + 180
                const dx = Math.sin(a), dy = -Math.cos(a)
                ctx.beginPath()
                ctx.moveTo(x - dx * len / 2, y - dy * len / 2)
                ctx.lineTo(x + dx * len / 2, y + dy * len / 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(x + dx * len / 2, y + dy * len / 2)
                ctx.lineTo(x + dx * len / 2 - dx * 5 + dy * 3.2, y + dy * len / 2 - dy * 5 - dx * 3.2)
                ctx.lineTo(x + dx * len / 2 - dx * 5 - dy * 3.2, y + dy * len / 2 - dy * 5 + dx * 3.2)
                ctx.closePath()
                ctx.fill()
            }
        }
    }

    // ---------- Marker of the place ----------
    Item {
        id: marker
        visible: Weather.hasPlace
        readonly property real px: {
            let d = W.lonToX(Weather.lon, root.zoom) - root.cwx
            if (d > root.ws / 2) d -= root.ws
            if (d < -root.ws / 2) d += root.ws
            return root.width / 2 + d
        }
        readonly property real py: root.height / 2 + W.latToY(Weather.lat, root.zoom) - root.cwy
        x: px - 16
        y: py - 16
        width: 32
        height: 32

        Rectangle {
            anchors.centerIn: parent
            width: 32; height: 32; radius: 16
            color: Theme.accent
            opacity: 0.28
        }
        Rectangle {
            anchors.centerIn: parent
            width: 16; height: 16; radius: 8
            color: Theme.accent
            border.width: 2
            border.color: Theme.island
        }
    }

    // ---------- Drag and wheel ----------
    MouseArea {
        id: drag
        anchors.fill: parent
        property real lx: 0
        property real ly: 0
        property real wheelAcc: 0
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: m => { lx = m.x; ly = m.y }
        onPositionChanged: m => {
            if (!pressed) return
            root.cwx -= m.x - lx
            root.cwy -= m.y - ly
            lx = m.x; ly = m.y
            root.clampCenter()
            gridT.restart()
        }
        onWheel: w => {
            wheelAcc += w.angleDelta.y
            if (Math.abs(wheelAcc) >= 120) {
                root.setZoom(root.zoom + (wheelAcc > 0 ? 1 : -1))
                wheelAcc = 0
                gridT.restart()
            }
        }
        onDoubleClicked: { root.setZoom(root.zoom + 1); gridT.restart() }
    }

    // ---------- Grid of values for the layers ----------
    function viewBox() {
        return {
            n: W.yToLat(cwy - height / 2, zoom), s: W.yToLat(cwy + height / 2, zoom),
            w: W.xToLon(cwx - width / 2, zoom), e: W.xToLon(cwx + width / 2, zoom)
        }
    }

    function ensureGrid() {
        if (!Weather.consent || width <= 0 || !Weather.open) return
        const v = viewBox()
        if (v.w < -180 || v.e > 180) {            // around the date line: use the whole range
            v.w = Math.max(-180, v.w); v.e = Math.min(180, v.e)
        }
        const g = Weather.grid
        const fresh = g && Date.now() - Weather.gridAt < 20 * 60000
        if (fresh && g.s <= v.s && g.n >= v.n && g.w <= v.w && g.e >= v.e
                && (g.n - g.s) <= (v.n - v.s) * 2.6 && (g.e - g.w) <= (v.e - v.w) * 2.6) return
        const mLat = (v.n - v.s) * 0.15, mLon = (v.e - v.w) * 0.15
        Weather.fetchGrid(Math.max(-85, v.s - mLat), Math.min(85, v.n + mLat), Math.max(-180, v.w - mLon), Math.min(180, v.e + mLon))
    }

    Timer { id: gridT; interval: 700; onTriggered: root.ensureGrid() }
    Connections {
        target: Weather
        function onConsentChanged() { gridT.restart() }
        function onOpenChanged() { if (Weather.open) gridT.restart() }
        function onGridBusyChanged() { if (!Weather.gridBusy) gridT.restart() }
        function onUnitsChanged() { gridT.restart() }
        function onPlacePicked() { gridT.restart() }
    }

    // ---------- Layer buttons (top left) ----------
    Rectangle {
        x: 10; y: 10
        height: 40
        width: layerRow.width + 12
        radius: 20
        color: Theme.scrim
        border.width: 1
        border.color: Theme.border

        Row {
            id: layerRow
            x: 6; y: 4
            spacing: 2

            Repeater {
                model: [{ id: "temp", icon: "l-temp" }, { id: "wind", icon: "l-wind" }, { id: "cloud", icon: "l-cloud" },
                        { id: "rain", icon: "l-rain" }, { id: "press", icon: "l-press" }]

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: Weather.layer === modelData.id
                    width: 32; height: 32; radius: 16
                    color: on ? Theme.accent : (m.containsMouse ? Theme.islandHover : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    WxIcon {
                        anchors.centerIn: parent
                        width: 18; height: 18
                        kind: parent.modelData.icon
                        color: parent.on ? Theme.island : Theme.foreground
                    }
                    MouseArea {
                        id: m
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Weather.set("layer", parent.modelData.id)
                    }
                }
            }
        }
    }

    // ---------- Legend (bottom left) ----------
    Rectangle {
        x: 10
        y: root.height - height - 10
        width: 184; height: 62
        radius: 18
        color: Theme.scrim
        border.width: 1
        border.color: Theme.border

        Text {
            x: 14; y: 9
            text: Weather.tr(Weather.layer === "wind" ? "windl" : Weather.layer)
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Canvas {
            id: legend
            x: 14; y: 28
            width: parent.width - 28
            height: 6

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const st = W.ramps[Weather.layer]
                const gr = ctx.createLinearGradient(0, 0, width, 0)
                for (let i = 0; i < st.length; i++)
                    gr.addColorStop(st[i][0], "rgb(" + Math.round(st[i][1]) + "," + Math.round(st[i][2]) + "," + Math.round(st[i][3]) + ")")
                ctx.fillStyle = gr
                ctx.beginPath()
                ctx.roundedRect ? ctx.roundedRect(0, 0, width, height, 3, 3) : ctx.rect(0, 0, width, height)
                ctx.fill()
            }
            Component.onCompleted: requestPaint()
        }

        Text {
            x: 14; y: 40
            text: Weather.grid ? root.rng.loText : Weather.tr("low")
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 40
            text: Weather.grid ? root.rng.hiText : Weather.tr("high")
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }

    // ---------- Buttons (bottom right) ----------
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        spacing: 6

        Repeater {
            model: [{ icon: "plus", act: "in" }, { icon: "minus", act: "out" }, { icon: "locate", act: "here" }]

            delegate: Rectangle {
                required property var modelData
                width: 32; height: 32; radius: 16
                color: bm.containsMouse ? Theme.islandHover : Theme.scrim
                border.width: 1
                border.color: Theme.border

                WxIcon {
                    anchors.centerIn: parent
                    width: 16; height: 16
                    kind: parent.modelData.icon
                    color: Theme.foreground
                }
                MouseArea {
                    id: bm
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.modelData.act === "in") root.setZoom(root.zoom + 1)
                        else if (parent.modelData.act === "out") root.setZoom(root.zoom - 1)
                        else root.recenter()
                        gridT.restart()
                    }
                }
            }
        }
    }

    // Credits required by the map and weather providers
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        text: "© OpenStreetMap · © CARTO · Open-Meteo"
        color: Theme.muted
        opacity: 0.8
        font.family: Theme.fontFamily
        font.pixelSize: 8
    }
}
