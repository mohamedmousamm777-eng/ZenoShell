import QtQuick

// Small vector icons: weather conditions, map layers and buttons. They follow the color given.
Canvas {
    id: root

    property string kind: "cloud"
    property color color: "white"
    property real lineW: 1.6

    implicitWidth: 24
    implicitHeight: 24

    onKindChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    function cloud(ctx, ox, oy, s) {
        ctx.beginPath()
        ctx.moveTo(ox + 5 * s, oy + 17 * s)
        ctx.arc(ox + 7 * s, oy + 13 * s, 4 * s, Math.PI * 0.55, Math.PI * 1.5)
        ctx.arc(ox + 12 * s, oy + 9.5 * s, 4.5 * s, Math.PI * 1.15, Math.PI * 1.95)
        ctx.arc(ox + 17 * s, oy + 13.5 * s, 3.5 * s, Math.PI * 1.5, Math.PI * 0.5)
        ctx.closePath()
    }

    function sun(ctx, cx, cy, r, rays) {
        ctx.beginPath()
        ctx.arc(cx, cy, r, 0, Math.PI * 2)
        ctx.fill()
        for (let i = 0; i < rays; i++) {
            const a = i * Math.PI * 2 / rays
            ctx.beginPath()
            ctx.moveTo(cx + Math.cos(a) * (r + 2), cy + Math.sin(a) * (r + 2))
            ctx.lineTo(cx + Math.cos(a) * (r + 4.2), cy + Math.sin(a) * (r + 4.2))
            ctx.stroke()
        }
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const s = Math.min(width, height) / 24
        ctx.scale(s, s)
        ctx.strokeStyle = color
        ctx.fillStyle = color
        ctx.lineWidth = lineW
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        const k = kind

        if (k === "clear") {
            sun(ctx, 12, 12, 4.6, 8)
        } else if (k === "moon") {
            ctx.beginPath()
            ctx.arc(12, 12, 7, 0.6 * Math.PI, 1.9 * Math.PI)
            ctx.arc(14.5, 9.5, 6, 1.75 * Math.PI, 0.7 * Math.PI, true)
            ctx.closePath()
            ctx.fill()
        } else if (k === "partly") {
            sun(ctx, 8.5, 8, 3.4, 8)
            ctx.globalAlpha = 1
            cloud(ctx, 3, 3, 0.95)
            ctx.fill()
        } else if (k === "cloud") {
            cloud(ctx, 0, 2, 1)
            ctx.fill()
        } else if (k === "fog") {
            ctx.beginPath(); ctx.moveTo(4, 8); ctx.lineTo(20, 8)
            ctx.moveTo(6, 12.5); ctx.lineTo(18, 12.5)
            ctx.moveTo(4, 17); ctx.lineTo(20, 17)
            ctx.stroke()
        } else if (k === "drizzle" || k === "rain") {
            cloud(ctx, 0, -1, 1)
            ctx.fill()
            ctx.beginPath()
            const n = k === "rain" ? 3 : 2
            for (let i = 0; i < n; i++) {
                const x = (k === "rain" ? 7 : 9) + i * (k === "rain" ? 5 : 6)
                ctx.moveTo(x, 17); ctx.lineTo(x - 1.4, 21)
            }
            ctx.stroke()
        } else if (k === "snow") {
            cloud(ctx, 0, -1, 1)
            ctx.fill()
            for (let i = 0; i < 3; i++) {
                ctx.beginPath()
                ctx.arc(7.5 + i * 4.5, 19.5, 1.2, 0, Math.PI * 2)
                ctx.fill()
            }
        } else if (k === "storm") {
            cloud(ctx, 0, -2, 1)
            ctx.fill()
            ctx.beginPath()
            ctx.moveTo(13, 14); ctx.lineTo(9.5, 19); ctx.lineTo(12.5, 19); ctx.lineTo(10.5, 23)
            ctx.stroke()
        // ----- Map layers
        } else if (k === "l-temp") {
            ctx.beginPath()
            ctx.moveTo(10, 14.5); ctx.lineTo(10, 5.5)
            ctx.arc(12, 5.5, 2, Math.PI, 0)
            ctx.lineTo(14, 14.5)
            ctx.stroke()
            ctx.beginPath(); ctx.arc(12, 17, 3.6, 0, Math.PI * 2); ctx.fill()
            ctx.beginPath(); ctx.moveTo(12, 7); ctx.lineTo(12, 16); ctx.stroke()
        } else if (k === "l-wind") {
            ctx.beginPath()
            ctx.moveTo(12, 20); ctx.lineTo(12, 5)
            ctx.moveTo(6.5, 10.5); ctx.lineTo(12, 5); ctx.lineTo(17.5, 10.5)
            ctx.stroke()
        } else if (k === "l-cloud") {
            cloud(ctx, 0, 2, 1)
            ctx.stroke()
        } else if (k === "l-rain") {
            ctx.beginPath()
            ctx.moveTo(12, 4); ctx.bezierCurveTo(16, 10, 18, 12.5, 18, 15.5)
            ctx.arc(12, 15.5, 6, 0, Math.PI)
            ctx.bezierCurveTo(6, 12.5, 8, 10, 12, 4)
            ctx.stroke()
        } else if (k === "l-press") {
            ctx.beginPath()
            ctx.moveTo(12, 3); ctx.lineTo(12, 21)
            ctx.moveTo(8, 7); ctx.lineTo(12, 3); ctx.lineTo(16, 7)
            ctx.moveTo(8, 17); ctx.lineTo(12, 21); ctx.lineTo(16, 17)
            ctx.stroke()
        // ----- Buttons
        } else if (k === "refresh") {
            ctx.beginPath()
            ctx.arc(12, 12, 7, 0.35 * Math.PI, 1.85 * Math.PI)
            ctx.stroke()
        } else if (k === "locate") {
            ctx.beginPath(); ctx.arc(12, 12, 6, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.arc(12, 12, 2, 0, Math.PI * 2); ctx.fill()
            ctx.beginPath()
            ctx.moveTo(12, 2); ctx.lineTo(12, 5); ctx.moveTo(12, 19); ctx.lineTo(12, 22)
            ctx.moveTo(2, 12); ctx.lineTo(5, 12); ctx.moveTo(19, 12); ctx.lineTo(22, 12)
            ctx.stroke()
        } else if (k === "plus") {
            ctx.beginPath(); ctx.moveTo(12, 6); ctx.lineTo(12, 18); ctx.moveTo(6, 12); ctx.lineTo(18, 12); ctx.stroke()
        } else if (k === "minus") {
            ctx.beginPath(); ctx.moveTo(6, 12); ctx.lineTo(18, 12); ctx.stroke()
        // ----- Metrics
        } else if (k === "m-uv") {
            sun(ctx, 12, 12, 3.6, 8)
        } else if (k === "m-hum") {
            ctx.beginPath()
            ctx.moveTo(12, 3.5); ctx.bezierCurveTo(16, 9, 18, 11.5, 18, 14.5)
            ctx.arc(12, 14.5, 6, 0, Math.PI)
            ctx.bezierCurveTo(6, 11.5, 8, 9, 12, 3.5)
            ctx.stroke()
        } else if (k === "m-wind") {
            ctx.beginPath()
            ctx.moveTo(3, 9); ctx.lineTo(14, 9); ctx.arc(14, 6.5, 2.5, Math.PI / 2, -Math.PI / 2, true)
            ctx.moveTo(3, 14); ctx.lineTo(18, 14); ctx.arc(18, 17, 3, -Math.PI / 2, Math.PI / 2)
            ctx.lineTo(10, 20)
            ctx.stroke()
        } else if (k === "m-vis") {
            ctx.beginPath()
            ctx.moveTo(2.5, 12); ctx.quadraticCurveTo(12, 3, 21.5, 12); ctx.quadraticCurveTo(12, 21, 2.5, 12)
            ctx.stroke()
            ctx.beginPath(); ctx.arc(12, 12, 2.6, 0, Math.PI * 2); ctx.fill()
        } else if (k === "sunrise" || k === "sunset") {
            ctx.beginPath(); ctx.arc(12, 17, 5, Math.PI, 0); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(3, 17); ctx.lineTo(21, 17); ctx.stroke()
            ctx.beginPath()
            if (k === "sunrise") { ctx.moveTo(12, 6); ctx.lineTo(12, 3); ctx.moveTo(10, 5); ctx.lineTo(12, 3); ctx.lineTo(14, 5) }
            else { ctx.moveTo(12, 3); ctx.lineTo(12, 6); ctx.moveTo(10, 4); ctx.lineTo(12, 6); ctx.lineTo(14, 4) }
            ctx.stroke()
        }
    }
}
