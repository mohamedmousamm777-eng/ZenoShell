import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services

SPage {
    id: root
    title: "About"
    subtitle: "ZenoShell: a Quickshell shell for niri and Hyprland."

    property string distro: ""

    FileView {
        id: osRelease
        path: "/etc/os-release"
        blockLoading: true
        printErrors: false
        Component.onCompleted: {
            const m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m)
            if (m) root.distro = m[1]
        }
    }

    SSection {
        title: "This installation"

        SRow {
            title: "Version"
            Text { text: Settings.version; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 13 }
        }

        SRow {
            title: "Compositor"
            Text { text: Compositor.kind; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 13 }
        }

        SRow {
            last: true
            title: "Distribution"
            Text { text: root.distro !== "" ? root.distro : "unknown"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: 13 }
        }
    }

    SSection {
        title: "Project"

        SRow {
            title: "Source code and updates"
            hint: "github.com/mohamedmousamm777-eng/ZenoShell. To update: git pull, then sh install.sh."
            last: true
            SButton {
                label: "Open on GitHub"
                onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/mohamedmousamm777-eng/ZenoShell"])
            }
        }
    }

    SSection {
        title: "Files"

        SRow {
            title: "Settings"
            hint: "~/.local/state/quickshell/  (settings.json, style.json, appearance.json)"
            last: true
            SButton {
                label: "Open folder"
                onClicked: Quickshell.execDetached(["xdg-open", Settings.stateDir])
            }
        }
    }
}
