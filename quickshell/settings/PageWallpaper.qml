import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.widgets

SPage {
    title: "Wallpaper, lock & idle"
    subtitle: "The wallpaper picker, the lock screen and what happens when you stop using the computer."

    SSection {
        title: "Wallpaper"

        SRow {
            last: true
            title: "Choose a wallpaper"
            hint: "Opens the picker with the images of your Wallpapers folder. The colors of the shell follow the one you pick. Also with Alt+W."
            SButton {
                label: "Open picker"
                accent: true
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "wallpaper", "toggle"])
            }
        }
    }

    SSection {
        title: "Animated wallpaper"

        SRow {
            title: "Play the animated wallpaper"
            hint: "Turn it off to save CPU and battery: the still frame stays and nothing is decoded.  Now: " + LiveWall.statusText
            Toggle {
                checked: Settings.liveEnabled
                onToggled: Settings.set("liveEnabled", !Settings.liveEnabled)
            }
        }

        SRow {
            title: "Smart pause"
            hint: "Pauses by itself (nothing is decoded) with a fullscreen window, on the lock screen, in Game Mode and Eco Mode, when the screen is off, and when the PC is struggling (CPU or RAM very high). It starts again when things calm down."
            Toggle {
                checked: Settings.livePause
                onToggled: Settings.set("livePause", !Settings.livePause)
            }
        }

        SRow {
            title: "Choose an animated wallpaper"
            hint: "Videos and GIFs from the Wallpapers_Video folder, next to Wallpapers. Always muted. Also with Alt+Shift+W."
            SButton {
                label: "Open picker"
                accent: true
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "wallpaper", "video"])
            }
        }

        SRow {
            last: true
            title: "Back to a still wallpaper"
            hint: "Forgets the animated one and keeps its still frame. Choosing an image with Alt+W does the same."
            SButton {
                label: "Stop"
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "livewall", "clear"])
            }
        }
    }

    SSection {
        title: "Lock screen"

        SRow {
            last: true
            title: "Lock now"
            hint: "Also with Alt+L."
            SButton {
                label: "Lock"
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"])
            }
        }
    }

    SSection {
        title: "When idle"

        SRow {
            title: "Lock the screen after"
            hint: "Counted from the last mouse or keyboard input. Needs a compositor that supports idle notifications (niri and Hyprland do)."
            SChoice {
                model: [{ id: "0", label: "Never" }, { id: "5", label: "5 min" }, { id: "10", label: "10 min" }, { id: "15", label: "15 min" }, { id: "30", label: "30 min" }]
                current: String(Settings.lockMin)
                onPicked: id => Settings.set("lockMin", parseInt(id))
            }
        }

        SRow {
            last: true
            title: "Turn the screen off after"
            hint: "The screen wakes up with the first movement. Videos and other things that keep the screen awake are respected."
            SChoice {
                model: [{ id: "0", label: "Never" }, { id: "5", label: "5 min" }, { id: "10", label: "10 min" }, { id: "15", label: "15 min" }, { id: "30", label: "30 min" }]
                current: String(Settings.screenOffMin)
                onPicked: id => Settings.set("screenOffMin", parseInt(id))
            }
        }
    }
}
