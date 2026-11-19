import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import qs.theme
import qs.services
import qs.widgets

// System Monitor: six tiles on top (CPU, RAM, GPU, Temp, Processes, Network); the one you click fills the
// panel below with its details. Readings come from SysStats and only run while this is open.
Item {
    id: root

    property bool narrow: false
    signal closeRequested()

    readonly property string view: SysStats.monitorView
    readonly property int nth: Math.max(1, SysStats.threads)
    readonly property color amber: "#e0b25a"
    readonly property color card: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.06)
    readonly property color cardOn: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
    readonly property color hair: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.09)
    property bool searching: false      // the search box has the keyboard
    readonly property bool wantsKeyboard: searching

    property int pending: -1            // process waiting for "Terminate / Force"
    property string sortBy: "cpu"
    property string query: ""

    function gb(b) { return (b / 1073741824).toFixed(1) + " GB" }
    function mb(b) { return (b / 1048576).toFixed(0) + " MB" }
    function shortRate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " M"
        if (b >= 1024) return Math.round(b / 1024) + " K"
        return Math.round(b) + " B"
    }
    function uptimeText(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return (d > 0 ? d + " d " : "") + (h > 0 || d > 0 ? h + " h " : "") + m + " min"
    }
    function tempTone(c) { return c >= 85 ? Theme.danger : (c >= 72 ? root.amber : Theme.accent) }

    // The busiest processes, filtered and sorted
    function sorted(by, q, n) {
        const ql = q.toLowerCase()
        const l = SysStats.procs.filter(p => ql === "" || p.name.toLowerCase().indexOf(ql) >= 0)
        l.sort((a, b) => by === "mem" ? b.mem - a.mem : b.cpu - a.cpu)
        return l.slice(0, n)
    }
    function topName() {
        const l = sorted("cpu", "", 1)
        return l.length > 0 ? l[0].name : ""
    }

    // ---------- Small pieces ----------
    component Txt: Text {
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    component Card: Rectangle {
        radius: 16
        color: root.card
    }

    component Kv: Item {
        property string k: ""
        property string v: ""
        implicitWidth: 120
        implicitHeight: 34
        Txt { y: 0; text: parent.k.toUpperCase(); color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 0.8 }
        Txt { y: 14; width: parent.width; text: parent.v; elide: Text.ElideRight; font.pixelSize: 12 }
    }

    component Tile: Item {
        id: t

        property string key: ""
        property string label: ""
        property string sub: ""
        property real frac: 0
        property color tone: Theme.accent
        property string mid: ""
        property bool ringed: true
        property string l1: ""
        property string l2: ""
        property color c1: Theme.accent
        property color c2: Theme.note
        readonly property bool sel: root.view === key

        height: 104

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: t.sel ? root.cardOn : (tm.containsMouse ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.09) : root.card)
            border.width: t.sel ? 1.5 : 0
            border.color: Theme.accent
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Txt { y: 8; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: t.label.toUpperCase(); color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 1 }

        // ring
        Item {
            id: ring
            visible: t.ringed
            x: (parent.width - 56) / 2
            y: 24
            width: 56; height: 56

            property real shown: t.frac
            Behavior on shown { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: root.hair
                    strokeWidth: 6
                    fillColor: "transparent"
                    PathAngleArc { centerX: 28; centerY: 28; radiusX: 24; radiusY: 24; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: t.tone
                    strokeWidth: 6
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 28; centerY: 28; radiusX: 24; radiusY: 24; startAngle: -90; sweepAngle: Math.max(0.01, 360 * Math.min(1, ring.shown)) }
                }
            }

            Txt { anchors.centerIn: parent; text: t.mid; font.pixelSize: 14; font.bold: true }
        }

        // two lines of text (processes, network)
        Column {
            visible: !t.ringed
            x: 0; y: 28
            width: parent.width
            height: 48
            spacing: 2
            Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: t.l1; color: t.c1; font.pixelSize: 15; font.bold: true }
            Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: t.l2; color: t.c2; font.pixelSize: t.key === "net" ? 15 : 11; font.bold: t.key === "net" }
        }

        Txt { y: 86; width: parent.width - 8; x: 4; horizontalAlignment: Text.AlignHCenter; text: t.sub; color: Theme.muted; font.pixelSize: 9; elide: Text.ElideRight }

        MouseArea {
            id: tm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.pending = -1; SysStats.setView(t.key) }
        }
    }

    // Graph with the current value written on it
    component GraphCard: Card {
        property string big: ""
        property color bigColor: Theme.foreground
        property string big2: ""
        property color big2Color: Theme.note
        property string sub: ""
        property var series: []
        property var colors: []
        property real maxV: 100
        property real minV: 0

        width: parent ? parent.width : 300
        // taller when the window is tall: the graph takes part of the extra space
        readonly property real extra: Math.max(0, Math.min(150, (root.height - 612) * 0.5))
        height: 168 + extra

        Row {
            x: 14; y: 12
            spacing: 10
            Txt { text: parent.parent.big; color: parent.parent.bigColor; font.pixelSize: 28; font.bold: true }
            Txt { text: parent.parent.big2; color: parent.parent.big2Color; font.pixelSize: 18; font.bold: true; visible: text !== ""; topPadding: 10 }
            Txt { text: parent.parent.sub + " · last 2 minutes"; color: Theme.muted; topPadding: 14 }
        }

        Graph {
            x: 14; y: 54
            width: parent.width - 28
            height: 90 + parent.extra
            series: parent.series
            colors: parent.colors
            maxV: parent.maxV
            minV: parent.minV
            rev: SysStats.histRev
        }

        Txt { x: 14; y: parent.height - 20; text: "2 min ago"; color: Theme.muted; font.pixelSize: 9 }
        Txt { x: parent.width - width - 14; y: parent.height - 20; text: "now"; color: Theme.muted; font.pixelSize: 9 }
    }

    component Chip: Rectangle {
        property string text: ""
        property bool on: false
        signal clicked()
        implicitWidth: ct.implicitWidth + 22
        implicitHeight: 24
        radius: 12
        color: on ? Theme.accent : (cm.containsMouse ? root.cardOn : root.card)
        Txt { id: ct; anchors.centerIn: parent; text: parent.text; color: parent.on ? Theme.island : Theme.muted; font.bold: parent.on }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    component Action: Item {
        property string text: ""
        property bool danger: false
        signal clicked()
        implicitWidth: at.implicitWidth + 14
        implicitHeight: 22
        Rectangle { anchors.fill: parent; radius: 11; color: am.containsMouse ? root.cardOn : "transparent" }
        Txt { id: at; anchors.centerIn: parent; text: parent.text; color: parent.danger ? Theme.danger : Theme.muted; font.pixelSize: 10 }
        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    component ProcTable: Column {
        id: pt
        property int rows: 5
        property string by: "cpu"
        property string q: ""
        width: parent ? parent.width : 300
        spacing: 0

        readonly property real cName: 0
        readonly property real cPid: width * 0.42
        readonly property real cCpu: width * 0.56
        readonly property real cMem: width * 0.69
        readonly property real cAct: width * 0.80

        Item {
            width: pt.width
            height: 20
            Txt { x: pt.cName; text: "NAME"; color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 0.8 }
            Txt { x: pt.cPid; text: "PID"; color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 0.8 }
            Txt { x: pt.cCpu; text: "CPU %"; color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 0.8 }
            Txt { x: pt.cMem; text: "RAM %"; color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 0.8 }
        }

        Repeater {
            model: root.sorted(pt.by, pt.q, pt.rows)

            delegate: Item {
                id: row
                required property var modelData
                width: pt.width
                height: 28

                Rectangle { width: parent.width; height: 1; color: root.hair }

                Txt { x: pt.cName; width: pt.cPid - 8; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.name; elide: Text.ElideRight; font.pixelSize: 12 }
                Txt { x: pt.cPid; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.pid; color: Theme.muted; font.family: "monospace" }
                Txt { x: pt.cCpu; anchors.verticalCenter: parent.verticalCenter; text: (row.modelData.cpu / root.nth).toFixed(1); font.family: "monospace" }
                Txt { x: pt.cMem; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.mem.toFixed(1); font.family: "monospace" }

                Row {
                    x: pt.width - width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Action { visible: root.pending !== row.modelData.pid; text: "✕"; onClicked: root.pending = row.modelData.pid }
                    Action { visible: root.pending === row.modelData.pid; text: "Terminate"; danger: true; onClicked: { SysStats.signal(row.modelData.pid, "TERM"); root.pending = -1 } }
                    Action { visible: root.pending === row.modelData.pid; text: "Force"; danger: true; onClicked: { SysStats.signal(row.modelData.pid, "KILL"); root.pending = -1 } }
                    Action { visible: root.pending === row.modelData.pid; text: "Cancel"; onClicked: root.pending = -1 }
                }
            }
        }

        Txt {
            visible: SysStats.procs.length === 0
            width: pt.width
            height: 40
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: "Reading processes..."
            color: Theme.muted
        }
    }

    // ---------- Header ----------
    Item {
        id: head
        width: parent.width
        height: 34

        Txt { x: 2; anchors.verticalCenter: parent.verticalCenter; text: "System Monitor"; font.pixelSize: 13; font.bold: true }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width - 30 - width - 8
            width: ev.implicitWidth + 18
            height: 20
            radius: 10
            color: root.card
            Txt { id: ev; anchors.centerIn: parent; text: "every 2 s"; color: Theme.muted; font.pixelSize: 10 }
        }

        Rectangle {
            x: parent.width - width
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26
            radius: 13
            color: xm.containsMouse ? root.cardOn : root.card
            Txt { anchors.centerIn: parent; text: "✕"; color: Theme.muted }
            MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeRequested() }
        }
    }

    // ---------- Tiles ----------
    Grid {
        id: tiles
        y: head.height + 4
        width: parent.width
        columns: root.narrow ? 3 : 6
        spacing: 8
        readonly property real tw: (width - (columns - 1) * spacing) / columns

        Tile {
            key: "cpu"; label: "CPU"; width: tiles.tw
            frac: SysStats.cpu; mid: Math.round(SysStats.cpu * 100)
            sub: SysStats.cores > 0 ? SysStats.cores + " cores" : SysStats.threads + " threads"
        }
        Tile {
            key: "ram"; label: "RAM"; width: tiles.tw; tone: Theme.note
            frac: SysStats.ram; mid: Math.round(SysStats.ram * 100)
            sub: (SysStats.ramUsed / 1073741824).toFixed(1) + " / " + (SysStats.ramTotal / 1073741824).toFixed(0) + " GB"
        }
        Tile {
            key: "gpu"; label: "GPU"; width: tiles.tw
            frac: SysStats.gpuPresent ? SysStats.gpuBusy : 0
            mid: SysStats.gpuPresent ? Math.round(SysStats.gpuBusy * 100) : "–"
            sub: SysStats.gpuPresent ? (SysStats.gpus.length > 1 ? SysStats.gpus.length + " GPUs" : SysStats.gpuVendor) : "not found"
        }
        Tile {
            key: "temp"; label: "Temp"; width: tiles.tw
            tone: root.tempTone(SysStats.maxTemp)
            frac: Math.max(0, Math.min(1, (SysStats.maxTemp - 30) / 70))
            mid: SysStats.temps.length > 0 ? Math.round(SysStats.maxTemp) + "°" : "–"
            sub: "sensors"
        }
        Tile {
            key: "proc"; label: "Processes"; width: tiles.tw; ringed: false
            l1: SysStats.tasks > 0 ? String(SysStats.tasks) : "–"; l2: "running"; c2: Theme.muted
            sub: root.topName() !== "" ? "top: " + root.topName() : "tasks"
        }
        Tile {
            key: "net"; label: "Network"; width: tiles.tw; ringed: false
            l1: "↓ " + root.shortRate(SysStats.netDown); l2: "↑ " + root.shortRate(SysStats.netUp)
            sub: "per second"
        }
    }

    // ---------- Detail of the selected tile ----------
    Flickable {
        id: detail
        x: 0
        y: tiles.y + tiles.height + 10
        width: parent.width
        height: parent.height - y
        contentWidth: width
        contentHeight: body.item ? body.item.implicitHeight + 4 : 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Loader {
            id: body
            width: detail.width
            sourceComponent: root.view === "ram" ? ramView : root.view === "gpu" ? gpuView : root.view === "temp" ? tempView
                           : root.view === "proc" ? procView : root.view === "net" ? netView : cpuView
        }
    }

    // CPU
    Component {
        id: cpuView
        Column {
            spacing: 10
            GraphCard { big: Math.round(SysStats.cpu * 100) + "%"; sub: "CPU"; series: [SysStats.hist.cpu]; colors: [Theme.accent] }
            Card {
                width: parent.width; height: 94
                Flow {
                    x: 14; y: 12; width: parent.width - 28; spacing: 6
                    readonly property real cw: (width - 6 * 3) / 4
                    Kv { width: parent.cw; k: "Frequency"; v: SysStats.freqMhz > 0 ? (SysStats.freqMhz / 1000).toFixed(1) + " GHz" : "–" }
                    Kv { width: parent.cw; k: "Load average"; v: SysStats.load.map(x => x.toFixed(1)).join(" · ") }
                    Kv { width: parent.cw; k: "Cores / threads"; v: (SysStats.cores > 0 ? SysStats.cores : "–") + " / " + SysStats.threads }
                    Kv { width: parent.cw; k: "Running for"; v: root.uptimeText(SysStats.uptime) }
                    Kv { width: parent.width; k: "Model"; v: SysStats.cpuModel !== "" ? SysStats.cpuModel : "–" }
                }
            }
            Card {
                width: parent.width; height: pc.implicitHeight + 40
                Txt { x: 14; y: 12; text: "BUSIEST PROCESSES"; color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 0.8 }
                Txt { x: parent.width - width - 14; y: 12; text: "CPU ÷ " + root.nth + " cores"; color: Theme.muted; font.pixelSize: 9 }
                ProcTable { id: pc; x: 14; y: 30; width: parent.width - 28; rows: 5; by: "cpu" }
            }
        }
    }

    // RAM
    Component {
        id: ramView
        Column {
            spacing: 10
            GraphCard { big: Math.round(SysStats.ram * 100) + "%"; sub: "RAM"; series: [SysStats.hist.ram]; colors: [Theme.note] }
            Card {
                width: parent.width; height: 122
                Txt { x: 14; y: 12; text: "MEMORY"; color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 0.8 }
                Txt { x: parent.width - width - 14; y: 12; text: root.gb(SysStats.ramTotal) + " total"; color: Theme.muted; font.pixelSize: 9 }
                Rectangle {
                    x: 14; y: 32; width: parent.width - 28; height: 10; radius: 5; color: root.hair; clip: true
                    Rectangle { width: parent.width * Math.min(1, SysStats.ramUsed / Math.max(1, SysStats.ramTotal)); height: parent.height; color: Theme.note }
                    Rectangle {
                        x: parent.width * Math.min(1, SysStats.ramUsed / Math.max(1, SysStats.ramTotal))
                        width: parent.width * Math.min(1, (SysStats.memCached + SysStats.memBuffers) / Math.max(1, SysStats.ramTotal))
                        height: parent.height; color: Qt.rgba(Theme.note.r, Theme.note.g, Theme.note.b, 0.4)
                    }
                }
                Flow {
                    x: 14; y: 56; width: parent.width - 28; spacing: 6
                    readonly property real cw: (width - 6 * 3) / 4
                    Kv { width: parent.cw; k: "In use"; v: root.gb(SysStats.ramUsed) }
                    Kv { width: parent.cw; k: "Cache"; v: root.gb(SysStats.memCached + SysStats.memBuffers) }
                    Kv { width: parent.cw; k: "Free"; v: root.gb(SysStats.memFree) }
                    Kv { width: parent.cw; k: "Swap"; v: SysStats.swapTotal > 0 ? root.gb(SysStats.swapTotal - SysStats.swapFree) + " / " + root.gb(SysStats.swapTotal) : "none" }
                }
            }
            Card {
                width: parent.width; height: pm.implicitHeight + 40
                Txt { x: 14; y: 12; text: "MOST MEMORY"; color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 0.8 }
                ProcTable { id: pm; x: 14; y: 30; width: parent.width - 28; rows: 5; by: "mem" }
            }
        }
    }

    // GPU
    Component {
        id: gpuView
        Column {
            spacing: 10
            Card {
                visible: !SysStats.gpuPresent
                width: parent.width; height: 80
                Txt { anchors.centerIn: parent; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: Theme.muted
                      text: "No supported graphics chip found. AMD and Intel (also the ones inside the CPU) are read from the system, NVIDIA needs nvidia-smi." }
            }
            GraphCard { visible: SysStats.gpuPresent; big: Math.round(SysStats.gpuBusy * 100) + "%"; sub: SysStats.gpus.length > 1 ? "Busiest GPU" : "GPU"; series: [SysStats.hist.gpu]; colors: [Theme.accent] }
            // One chip: its numbers in a single card. Several (for example the one inside the CPU and a separate card): one card each.
            Repeater {
                model: SysStats.gpus.length > 1 ? SysStats.gpus : []

                delegate: Card {
                    required property var modelData
                    width: parent.width; height: 112

                    Txt { x: 14; y: 12; text: modelData.maker + " · " + (modelData.integrated ? "inside the CPU" : "separate card"); font.bold: true }
                    Txt { x: parent.width - width - 14; y: 12; color: Theme.accent; font.bold: true
                          text: modelData.busyKnown ? Math.round(modelData.busy * 100) + "%" + (modelData.est ? " (estimated)" : "") : "–" }
                    Flow {
                        x: 14; y: 44; width: parent.width - 28; spacing: 6
                        readonly property real cw: (width - 6 * 3) / 4
                        Kv { width: parent.cw; k: "Video memory"; v: modelData.vramTotal > 0 ? root.gb(modelData.vramUsed) + " / " + root.gb(modelData.vramTotal) : "–" }
                        Kv { width: parent.cw; k: "Clock"; v: modelData.clock > 0 ? modelData.clock + " MHz" : "–" }
                        Kv { width: parent.cw; k: "Power"; v: modelData.power > 0 ? modelData.power + " W" : "–" }
                        Kv { width: parent.cw; k: "Temperature"; v: modelData.temp > 0 ? modelData.temp + " °C" : "–" }
                    }
                }
            }

            Card {
                visible: SysStats.gpuPresent && SysStats.gpus.length <= 1
                width: parent.width; height: 84
                Flow {
                    x: 14; y: 12; width: parent.width - 28; spacing: 6
                    readonly property real cw: (width - 6 * 3) / 4
                    Kv { width: parent.cw; k: "Video memory"; v: SysStats.gpuVramTotal > 0 ? root.gb(SysStats.gpuVramUsed) + " / " + root.gb(SysStats.gpuVramTotal) : "–" }
                    Kv { width: parent.cw; k: "Clock"; v: SysStats.gpuClock > 0 ? SysStats.gpuClock + " MHz" : "–" }
                    Kv { width: parent.cw; k: "Power"; v: SysStats.gpuPower > 0 ? SysStats.gpuPower + " W" : "–" }
                    Kv { width: parent.cw; k: "Maker"; v: SysStats.gpuVendor }
                }
            }
        }
    }

    // Temperatures and fans
    Component {
        id: tempView
        Column {
            spacing: 10
            GraphCard { big: SysStats.temps.length > 0 ? Math.round(SysStats.maxTemp) + "°" : "–"; bigColor: root.tempTone(SysStats.maxTemp); sub: "Hottest"; series: [SysStats.hist.temp]; colors: [root.amber]; minV: 20; maxV: 100 }
            Card {
                width: parent.width; height: sensCol.implicitHeight + 54
                Txt { x: 14; y: 12; text: "ALL SENSORS"; color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 0.8 }
                RowLayout {
                    x: parent.width - width - 14; y: 6; height: 24; spacing: 8
                    Txt { Layout.alignment: Qt.AlignVCenter; text: "Warn above"; color: Theme.muted; font.pixelSize: 10 }
                    Action { Layout.alignment: Qt.AlignVCenter; text: "−"; onClicked: { SysStats.alertTemp = Math.max(50, SysStats.alertTemp - 5); SysStats.saveCfg() } }
                    Txt { Layout.alignment: Qt.AlignVCenter; text: SysStats.alertTemp + " °C"; font.pixelSize: 10 }
                    Action { Layout.alignment: Qt.AlignVCenter; text: "+"; onClicked: { SysStats.alertTemp = Math.min(110, SysStats.alertTemp + 5); SysStats.saveCfg() } }
                    Toggle { Layout.alignment: Qt.AlignVCenter; Layout.preferredWidth: 32; Layout.preferredHeight: 18; implicitWidth: 32; implicitHeight: 18; checked: SysStats.alertOn; onToggled: SysStats.setAlert(!SysStats.alertOn) }
                }
                Column {
                    id: sensCol
                    x: 14; y: 36; width: parent.width - 28
                    Repeater {
                        model: SysStats.temps.slice().sort((a, b) => b.c - a.c)
                        delegate: Item {
                            required property var modelData
                            width: sensCol.width; height: 26
                            Rectangle { width: parent.width; height: 1; color: root.hair }
                            Txt { width: parent.width * 0.5; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; elide: Text.ElideRight; font.pixelSize: 12 }
                            Txt { x: parent.width * 0.52; anchors.verticalCenter: parent.verticalCenter; text: Math.round(modelData.c) + " °C"; font.family: "monospace" }
                            Rectangle {
                                x: parent.width * 0.66; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.34; height: 5; radius: 2.5; color: root.hair
                                Rectangle { width: parent.width * Math.max(0, Math.min(1, (modelData.c - 20) / 80)); height: parent.height; radius: 2.5; color: root.tempTone(modelData.c) }
                            }
                        }
                    }
                    Repeater {
                        model: SysStats.fans
                        delegate: Item {
                            required property var modelData
                            width: sensCol.width; height: 26
                            Rectangle { width: parent.width; height: 1; color: root.hair }
                            Txt { width: parent.width * 0.5; anchors.verticalCenter: parent.verticalCenter; text: modelData.name; elide: Text.ElideRight; font.pixelSize: 12 }
                            Txt { x: parent.width * 0.52; anchors.verticalCenter: parent.verticalCenter; text: Math.round(modelData.rpm) + " rpm"; font.family: "monospace" }
                            Rectangle {
                                x: parent.width * 0.66; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.34; height: 5; radius: 2.5; color: root.hair
                                Rectangle { width: parent.width * Math.max(0, Math.min(1, modelData.rpm / 3000)); height: parent.height; radius: 2.5; color: Theme.note }
                            }
                        }
                    }
                    Txt { visible: SysStats.temps.length === 0; width: parent.width; height: 40; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter; color: Theme.muted; text: "This computer does not report any temperature sensor." }
                }
            }
        }
    }

    // Processes
    Component {
        id: procView
        Column {
            spacing: 10
            Card {
                width: parent.width; height: 60 + pl.implicitHeight
                RowLayout {
                    x: 14; y: 12; width: parent.width - 28; height: 28; spacing: 6
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 28; radius: 14; color: root.card
                        TextInput {
                            id: searchInput
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.foreground
                            font.family: Theme.fontFamily; font.pixelSize: 11
                            clip: true
                            text: root.query
                            onTextChanged: root.query = text
                            onActiveFocusChanged: root.searching = activeFocus
                            Keys.onEscapePressed: { text = ""; focus = false }
                        }
                        Txt { visible: searchInput.text === ""; x: 12; anchors.verticalCenter: parent.verticalCenter; text: "Search a process"; color: Theme.muted }
                    }
                    Chip { Layout.alignment: Qt.AlignVCenter; text: "By CPU"; on: root.sortBy === "cpu"; onClicked: root.sortBy = "cpu" }
                    Chip { Layout.alignment: Qt.AlignVCenter; text: "By RAM"; on: root.sortBy === "mem"; onClicked: root.sortBy = "mem" }
                }
                ProcTable { id: pl; x: 14; y: 50; width: parent.width - 28; rows: 40; by: root.sortBy; q: root.query }
            }
            Txt { width: parent.width - 8; x: 4; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: 10
                  text: "CPU % is the share of the whole processor (divided by " + root.nth + " cores). Terminate asks the program to close; Force ends it at once." }
        }
    }

    // Network
    Component {
        id: netView
        Column {
            spacing: 10
            GraphCard {
                big: "↓ " + (SysStats.netDown / 1048576).toFixed(1); bigColor: Theme.accent
                big2: "↑ " + (SysStats.netUp / 1048576).toFixed(1); big2Color: Theme.note
                sub: "MB/s"
                series: [SysStats.hist.down, SysStats.hist.up]
                colors: [Theme.accent, Theme.note]
                maxV: SysStats.histRev >= 0 ? Math.max(2, Math.max.apply(null, SysStats.hist.down.concat(SysStats.hist.up, [0])) * 1.15) : 2
            }
            Card {
                width: parent.width; height: ifc.implicitHeight + 40
                Txt { x: 14; y: 12; text: "INTERFACES"; color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 0.8 }
                Column {
                    id: ifc
                    x: 14; y: 32; width: parent.width - 28
                    Repeater {
                        model: SysStats.ifaces
                        delegate: Item {
                            required property var modelData
                            width: ifc.width; height: 26
                            Rectangle { width: parent.width; height: 1; color: root.hair }
                            Txt { anchors.verticalCenter: parent.verticalCenter; text: modelData.name; font.pixelSize: 12 }
                            Txt { x: parent.width * 0.5; anchors.verticalCenter: parent.verticalCenter; text: "↓ " + SysStats.fmtRate(modelData.down); color: Theme.accent; font.family: "monospace" }
                            Txt { x: parent.width * 0.76; anchors.verticalCenter: parent.verticalCenter; text: "↑ " + SysStats.fmtRate(modelData.up); color: Theme.note; font.family: "monospace" }
                        }
                    }
                }
            }
            Card {
                width: parent.width; height: 56
                Flow {
                    x: 14; y: 11; width: parent.width - 28; spacing: 6
                    Kv { width: (parent.width - 6) / 2; k: "Downloaded since boot"; v: root.gb(SysStats.totalRx) }
                    Kv { width: (parent.width - 6) / 2; k: "Uploaded since boot"; v: root.gb(SysStats.totalTx) }
                }
            }
        }
    }

    // Esc leaves the search box first, then closes the monitor
    Keys.onEscapePressed: root.closeRequested()
}
