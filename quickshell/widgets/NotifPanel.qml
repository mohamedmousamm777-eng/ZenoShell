import QtQuick
import qs.theme
import qs.services

// Panel: notifications, history and do-not-disturb
//  Inbox   = the notifications still alive (as before), grouped by app
//  History = the saved ones (NotifStore), read from the file only while this tab is open
Item {
    id: root

    width: 340
    height: 420

    property int tab: 0                       // 0 Inbox, 1 History
    property string query: ""
    property bool searching: false
    property var closed: ({})                 // app -> true when its group is folded
    property int limit: 100                   // History rows shown (more on request)
    property var rows: []
    property bool confirmClear: false

    // Same name as the Wi-Fi page: the host gives the keyboard to the panel while it is true
    readonly property bool needsKeyboard: searching

    readonly property bool holding: visible && tab === 1
    property bool held: false

    onHoldingChanged: syncHold()
    function syncHold() {
        if (holding && !held) { held = true; NotifStore.acquire() }
        else if (!holding && held) { held = false; NotifStore.release() }
    }

    // ---------- Rows: [{ kind: "h", app, n, open } | { kind: "i", ... } | { kind: "more", rest }] ----------
    function liveItems() {
        const vals = NotifCenter.list.values
        const out = []
        for (let i = vals.length - 1; i >= 0; i--) {              // newest first
            const n = vals[i]
            out.push({ app: n.appName || "?", summary: n.summary || "", body: n.body || "",
                       urg: n.urgency === 2 ? 2 : 1, t: 0, ref: n })
        }
        return out
    }

    function build() {
        const q = query.trim().toLowerCase()
        let src = tab === 0 ? liveItems() : NotifStore.entries
        if (q !== "") src = src.filter(e => (e.app + " " + e.summary + " " + e.body).toLowerCase().indexOf(q) >= 0)

        const total = src.length
        const lim = tab === 1 ? limit : total
        const counts = {}
        const order = []
        const map = {}
        for (let i = 0; i < total; i++) {
            const e = src[i]
            counts[e.app] = (counts[e.app] || 0) + 1
            if (i < lim) {
                if (!map[e.app]) { map[e.app] = []; order.push(e.app) }
                map[e.app].push(e)
            }
        }

        const out = []
        for (let g = 0; g < order.length; g++) {
            const a = order[g]
            const open = !closed[a]
            out.push({ kind: "h", app: a, n: counts[a], open: open })
            if (open) {
                const items = map[a]
                for (let i = 0; i < items.length; i++) out.push(Object.assign({ kind: "i" }, items[i]))
            }
        }
        if (total > lim) out.push({ kind: "more", rest: total - lim })
        rows = out
    }

    function rebuildSoon() { Qt.callLater(build) }

    onTabChanged: { limit = 100; confirmClear = false; rebuildSoon() }
    onQueryChanged: { limit = 100; rebuildSoon() }
    onClosedChanged: rebuildSoon()
    onLimitChanged: rebuildSoon()

    Connections {
        target: NotifStore
        function onEntriesChanged() { if (root.tab === 1) root.rebuildSoon() }
    }
    Connections {
        target: NotifCenter.list
        function onValuesChanged() { if (root.tab === 0) root.rebuildSoon() }
    }

    function toggleGroup(app) {
        const c = Object.assign({}, closed)
        c[app] = !c[app]
        closed = c
    }

    function clearGroup(app) {
        const vals = NotifCenter.list.values
        const arr = []
        for (let i = 0; i < vals.length; i++) if ((vals[i].appName || "?") === app) arr.push(vals[i])
        for (let i = 0; i < arr.length; i++) arr[i].dismiss()
    }

    function stamp(t) {
        if (!t) return ""
        const d = new Date(t)
        const now = new Date()
        const time = Qt.formatDateTime(d, "HH:mm")
        if (d.toDateString() === now.toDateString()) return time
        return d.toLocaleString(Qt.locale("C"), "d MMM") + " " + time        // English month, the interface is in English
    }

    function closeSearch() { searching = false; query = ""; searchField.text = "" }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: root.confirmClear = false
    }

    Rectangle {
        x: 10; y: 10
        width: parent.width - 20
        height: parent.height - 20
        radius: 22
        color: Theme.surfaceSoft

        Text {
            x: 18; y: 16
            text: "Notifications"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
        }

        // Do not disturb
        Rectangle {
            id: dndBtn
            anchors.right: parent.right
            anchors.rightMargin: clearText.visible ? clearText.width + 30 : 14
            y: 12
            width: 28; height: 28
            radius: 14
            color: NotifCenter.dnd ? Theme.accent : (dndMouse.containsMouse ? Theme.islandHover : Theme.island)
            Behavior on color { ColorAnimation { duration: 120 } }

            Glyph {
                anchors.centerIn: parent
                kind: "focus"
                size: 14
                color: NotifCenter.dnd ? Theme.island : Theme.foreground
            }

            MouseArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotifCenter.toggleDnd()
            }
        }

        // Clear: the Inbox, or (two clicks) the saved history
        Text {
            id: clearText
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 20
            visible: root.tab === 0 ? NotifCenter.count > 0 : NotifStore.entries.length > 0
            text: root.tab === 0 ? "Clear" : (root.confirmClear ? "Sure?" : "Delete")
            color: root.tab === 1 && root.confirmClear ? Theme.danger : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11

            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.tab === 0) { NotifCenter.clearAll(); return }
                    if (root.confirmClear) {
                        root.confirmClear = false
                        confirmTimer.stop()
                        NotifStore.clear()
                    } else {
                        root.confirmClear = true
                        confirmTimer.restart()
                    }
                }
            }
        }

        // Tabs and search button
        Row {
            x: 14; y: 48
            spacing: 6

            Repeater {
                model: [{ label: "Inbox", idx: 0 }, { label: "History", idx: 1 }]

                delegate: Rectangle {
                    id: tabPill
                    required property var modelData
                    readonly property bool on: root.tab === modelData.idx
                    width: pillText.implicitWidth + 24
                    height: 26
                    radius: 13
                    color: on ? Theme.accent : (pillMouse.containsMouse ? Theme.islandHover : Theme.island)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: pillText
                        anchors.centerIn: parent
                        text: tabPill.modelData.label + (tabPill.modelData.idx === 0 && NotifCenter.count > 0 ? "  " + NotifCenter.count : "")
                        color: tabPill.on ? Theme.island : Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: tabPill.on
                    }

                    MouseArea {
                        id: pillMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = tabPill.modelData.idx
                    }
                }
            }
        }

        Rectangle {
            id: searchBtn
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 48
            width: searchBtnText.implicitWidth + 24
            height: 26
            radius: 13
            color: root.searching ? Theme.accent : (searchBtnMouse.containsMouse ? Theme.islandHover : Theme.island)
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                id: searchBtnText
                anchors.centerIn: parent
                text: "Search"
                color: root.searching ? Theme.island : Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            MouseArea {
                id: searchBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.searching) root.closeSearch()
                    else { root.searching = true; searchField.forceActiveFocus() }
                }
            }
        }

        // Search box
        Rectangle {
            id: searchBox
            x: 14; y: 80
            width: parent.width - 28
            height: 28
            radius: 14
            color: Theme.island
            visible: root.searching

            TextInput {
                id: searchField
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
                clip: true
                selectByMouse: true
                onTextChanged: root.query = text
                Keys.onEscapePressed: event => { root.closeSearch(); event.accepted = true }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 14
                verticalAlignment: Text.AlignVCenter
                visible: searchField.text === ""
                text: root.tab === 0 ? "Search the inbox" : "Search the history"
                color: Theme.muted
                opacity: 0.7
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        // Empty states
        Text {
            x: 20; y: root.searching ? 114 : 84
            width: parent.width - 40
            height: parent.height - y - 10
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            visible: root.rows.length === 0
            text: {
                if (root.query.trim() !== "") return "Nothing found"
                if (root.tab === 1) {
                    if (NotifStore.loading) return "Loading…"
                    return NotifStore.saveHistory ? "No saved notifications" : "History is off\nTurn on \"Save history\" in Settings"
                }
                return NotifCenter.dnd ? "Do not disturb\n" + NotifCenter.dndText : "No notifications"
            }
            color: Theme.muted
            opacity: 0.7
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        ListView {
            id: list
            x: 10; y: root.searching ? 114 : 84
            width: parent.width - 20
            height: parent.height - y - 10
            spacing: 6
            clip: true
            model: root.rows

            delegate: Item {
                id: d

                required property var modelData
                readonly property var r: modelData

                width: ListView.view.width
                height: r.kind === "h" ? 24 : (r.kind === "more" ? 30 : card.height)

                // ----- group header -----
                Item {
                    anchors.fill: parent
                    visible: d.r.kind === "h"

                    Text {
                        id: arrow
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: Theme.muted
                        font.pixelSize: 15
                        rotation: d.r.open ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        x: 22
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 22 - (groupClear.visible ? 50 : 0) - 8
                        text: d.r.app + "  ·  " + d.r.n
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: groupClear.visible ? 52 : 0
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleGroup(d.r.app)
                    }

                    Text {
                        id: groupClear
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.tab === 0
                        text: "Clear"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearGroup(d.r.app)
                        }
                    }
                }

                // ----- "show more" -----
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    visible: d.r.kind === "more"
                    color: moreMouse.containsMouse ? Theme.islandHover : Theme.island

                    Text {
                        anchors.centerIn: parent
                        text: "Show more (" + d.r.rest + ")"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: moreMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.limit += 100
                    }
                }

                // ----- one notification -----
                Rectangle {
                    id: card
                    width: parent.width
                    height: d.r.kind === "i" ? nText.implicitHeight + 16 : 0
                    radius: 14
                    color: Theme.island
                    visible: d.r.kind === "i"

                    Rectangle {
                        visible: d.r.urg === 2
                        x: 0; y: 12
                        width: 3; height: parent.height - 24
                        radius: 2
                        color: Theme.danger
                    }

                    Column {
                        id: nText
                        x: 12; y: 8
                        width: parent.width - 24 - (d.r.ref ? 16 : 0)
                        spacing: 2

                        Item {
                            width: parent.width
                            height: when.implicitHeight

                            Text {
                                width: parent.width - when.implicitWidth - 6
                                text: d.r.app
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            Text {
                                id: when
                                anchors.right: parent.right
                                text: root.stamp(d.r.t)
                                color: Theme.muted
                                opacity: 0.8
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            width: parent.width
                            text: d.r.summary
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: d.r.body
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            textFormat: Text.StyledText
                            maximumLineCount: 3
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                    }

                    // × only for the live notifications
                    Text {
                        visible: d.r.ref !== undefined && d.r.ref !== null
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        y: 5
                        text: "×"
                        color: Theme.muted
                        font.pixelSize: 16

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { try { d.r.ref.dismiss() } catch (e) {} }
                        }
                    }
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            NotifCenter.unread = false
            rebuildSoon()
        } else {
            closeSearch()
            confirmClear = false
        }
    }

    Component.onCompleted: {
        if (visible) NotifCenter.unread = false
        syncHold()
        build()
    }

    Component.onDestruction: {
        if (held) { held = false; NotifStore.release() }
    }
}
