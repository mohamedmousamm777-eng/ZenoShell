import QtQuick
import qs.theme
import qs.services
import qs.widgets

SPage {
    id: page

    title: "Notifications & OSD"
    subtitle: "Do Not Disturb, the notification history and the volume / brightness indicator."

    property bool confirmDelete: false

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: page.confirmDelete = false
    }

    onVisibleChanged: if (visible) NotifStore.refreshCount()
    Component.onCompleted: NotifStore.refreshCount()

    SSection {
        title: "Do Not Disturb"

        SRow {
            title: "Do Not Disturb"
            hint: NotifCenter.dnd ? NotifCenter.dndText : "Notifications stop popping up; they stay in the notification center. Also with Alt+D."
            last: !NotifCenter.dnd
            Toggle {
                checked: NotifCenter.dnd
                onToggled: NotifCenter.setDnd(!NotifCenter.dnd, 0)
            }
        }

        SRow {
            visible: NotifCenter.dnd
            height: visible ? implicitHeight : 0
            last: true
            title: "Turn off after"
            hint: "Do Not Disturb switches itself off when the time is up."
            SChoice {
                model: [{ id: "30", label: "30 min" }, { id: "60", label: "1 h" }, { id: "120", label: "2 h" }, { id: "0", label: "Never" }]
                current: String(NotifCenter.dndMinutes)
                onPicked: id => NotifCenter.setDnd(true, parseInt(id))
            }
        }
    }

    SSection {
        title: "History"

        SRow {
            title: "Save history"
            hint: "Keeps the last 30 days (at most 500) of notifications in ~/.local/state/quickshell/notifs.jsonl, so the History tab survives a restart. The text of your messages is saved too: turn this off if you do not want that."
            last: !NotifStore.saveHistory
            Toggle {
                checked: NotifStore.saveHistory
                onToggled: NotifStore.setSaveHistory(!NotifStore.saveHistory)
            }
        }

        SRow {
            last: true
            title: "Delete history"
            hint: NotifStore.total < 0 ? "Removes every saved notification."
                                       : (NotifStore.total === 1 ? "1 saved notification." : NotifStore.total + " saved notifications.")
            SButton {
                label: page.confirmDelete ? "Click again to delete" : "Delete"
                onClicked: {
                    if (page.confirmDelete) {
                        page.confirmDelete = false
                        confirmTimer.stop()
                        NotifStore.clear()
                    } else {
                        page.confirmDelete = true
                        confirmTimer.restart()
                    }
                }
            }
        }
    }

    SSection {
        title: "Volume & brightness indicator"

        SRow {
            title: "Show the indicator"
            hint: "The small bar that appears when volume or brightness change. Its look follows the style."
            last: !Settings.osdEnabled
            Toggle {
                checked: Settings.osdEnabled
                onToggled: Settings.set("osdEnabled", !Settings.osdEnabled)
            }
        }

        SRow {
            visible: Settings.osdEnabled
            height: visible ? implicitHeight : 0
            title: "Stays on screen for"
            SChoice {
                model: [{ id: "1000", label: "1 s" }, { id: "1500", label: "1.5 s" }, { id: "2500", label: "2.5 s" }, { id: "4000", label: "4 s" }]
                current: String(Settings.osdMs)
                onPicked: id => Settings.set("osdMs", parseInt(id))
            }
        }

        SRow {
            visible: Settings.osdEnabled
            height: visible ? implicitHeight : 0
            last: true
            title: "Preview"
            SButton {
                label: "Show now"
                onClicked: OsdState.show("volume")
            }
        }
    }
}
