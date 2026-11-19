import QtQuick
import qs.theme
import qs.services

// Notifications, processor and temperature
Capsule {
    id: root

    Component.onCompleted: SysStats.users++
    Component.onDestruction: SysStats.users--

    Chip { kind: "bell"; label: String(NotifCenter.count) }
    Chip { kind: "cpu"; label: Math.round(SysStats.cpu * 100) + "%" }
    Chip { visible: SysStats.maxTemp > 0; kind: "temp"; label: Math.round(SysStats.maxTemp) + "°" }
}
