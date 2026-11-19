import QtQuick
import Quickshell
import qs.services

// Time and date strings for the looks (the Clock island only appears for the calendar, the launcher, etc.)
Item {
    id: root

    SystemClock { id: sc; precision: SystemClock.Minutes }

    readonly property var loc: Qt.locale("en_US")
    readonly property string fmt: Settings.timeFormat.replace("AP", "ap").replace(/^h:/, "hh:")
    readonly property string full: loc.toString(sc.date, fmt)
    readonly property string hhmm: full.split(" ")[0]
    readonly property string ampm: full.indexOf(" ") > 0 ? full.split(" ")[1] : ""
    function date(f) { return loc.toString(sc.date, f) }
}
