pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Open windows (apps), the same on niri and Hyprland (wlr foreign toplevel protocol).
// Used by the open-apps strip of the Classic bar and by the dock.
Singleton {
    id: root

    readonly property var all: ToplevelManager.toplevels.values
    readonly property var active: ToplevelManager.activeToplevel

    // One entry per app: the first window found, with how many it has
    readonly property var apps: {
        const out = []
        const seen = {}
        for (let i = 0; i < all.length; i++) {
            const t = all[i]
            const id = t.appId || ""
            if (seen[id] !== undefined) { out[seen[id]].count++; continue }
            seen[id] = out.length
            out.push({ appId: id, title: t.title, top: t, count: 1, active: t === active })
            if (t === active) out[out.length - 1].active = true
        }
        // the app of the focused window stays marked also when it has several windows
        for (let k = 0; k < out.length; k++)
            for (let i = 0; i < all.length; i++)
                if (all[i] === active && (all[i].appId || "") === out[k].appId) out[k].active = true
        return out
    }

    // Icon name for an app id (looks in the installed .desktop files first)
    function iconFor(appId) {
        if (!appId) return "application-x-executable"
        let e = null
        try { e = DesktopEntries.heuristicLookup(appId) } catch (err) {}
        if (e && e.icon) return e.icon
        return appId.toLowerCase()
    }

    function nameFor(appId) {
        let e = null
        try { e = DesktopEntries.heuristicLookup(appId) } catch (err) {}
        return e && e.name ? e.name : appId
    }

    function focusApp(appId) {
        for (let i = 0; i < all.length; i++)
            if ((all[i].appId || "") === appId) { all[i].activate(); return true }
        return false
    }

    function closeApp(appId) {
        for (let i = 0; i < all.length; i++)
            if ((all[i].appId || "") === appId) { all[i].close(); return }
    }
}
