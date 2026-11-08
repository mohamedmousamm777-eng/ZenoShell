import QtQuick

// A page that does not exist until it is needed.
// It is created the first time `wanted` is true and freed `keepMs` (a minute) after `wanted` goes back to false
// (so a page opened again soon keeps its state). The caller does the fade (opacity / visible) on this
// element exactly as it did on the page itself; the page is declared in `sourceComponent`.
// The properties and reset() below read the page if it exists, so the rest of the code keeps working.
Loader {
    id: lz

    property bool wanted: false
    property int keepMs: 60000
    property bool resetOnLoad: false            // call page.reset() right after creating it

    readonly property bool dragging: item ? item.dragging === true : false
    readonly property bool needsKeyboard: item ? item.needsKeyboard === true : false
    readonly property string query: (item && item.query !== undefined) ? String(item.query) : ""
    readonly property real itemImplicitHeight: item ? item.implicitHeight : 0

    function reset() { if (item && item.reset) item.reset() }

    active: wanted || hold.running
    onWantedChanged: { if (wanted) hold.stop(); else hold.restart() }
    onLoaded: if (resetOnLoad) reset()

    Timer { id: hold; interval: lz.keepMs }
}
