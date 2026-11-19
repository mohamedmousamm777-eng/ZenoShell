import QtQuick
import Quickshell
import qs.theme
import qs.services

SPage {
    title: "Profile & lock screen"
    subtitle: "Your name and photo, and how the lock screen looks."

    Component.onCompleted: Profile.refresh()

    SSection {
        title: "Profile"

        SRow {
            title: "Photo"
            hint: "Put your images in the folder  ~/Immagini/Profile  and they show up here. Used on the lock screen."
            SButton { label: "Refresh"; onClicked: Profile.refresh() }
        }
        Item {
            width: parent.width
            height: picker.implicitHeight + 16
            PhotoPicker { id: picker; x: 12; y: 0; width: parent.width - 24 }
        }

        SRow {
            title: "Photo shape"
            SChoice {
                model: [{ id: "circle", label: "Circle" }, { id: "rounded", label: "Rounded" }, { id: "square", label: "Square" }]
                current: Profile.shape
                onPicked: id => Profile.setShape(id)
            }
        }

        SRow {
            title: "Name"
            hint: "Shown on the lock screen. Empty = your user name (" + Profile.user + ")."
            STextField { text: Profile.name; placeholder: Profile.user; onCommitted: v => Profile.setName(v) }
        }

        SRow {
            last: true
            title: "Place"
            hint: "For example the city you live in. Shown under your name."
            STextField { text: Profile.place; placeholder: "Not set"; onCommitted: v => Profile.setPlace(v) }
        }
    }

    SSection {
        title: "Lock screen"

        SRow {
            title: "Style"
            hint: Profile.lockStyles.find(s => s.id === Profile.lockStyle).hint
            SChoice {
                model: Profile.lockStyles
                current: Profile.lockStyle
                onPicked: id => Profile.setLockStyle(id)
            }
        }

        SRow {
            title: "Clock position"
            hint: "Where the clock sits on the screen."
            PosGrid { current: Profile.clockAt; onPicked: c => Profile.setClockPos(c) }
        }

        SRow {
            title: "Login position"
            hint: "Where the password field (or the lock pill) sits."
            PosGrid { current: Profile.loginAt; onPicked: c => Profile.setLoginPos(c) }
        }

        SRow {
            last: true
            title: "Try it"
            hint: "Locks the screen for 12 seconds and unlocks by itself. Positions go back to the style's own with Reset."
            Row {
                spacing: 8
                SButton { label: "Reset positions"; onClicked: Profile.resetPositions() }
                SButton { label: "Test lock"; accent: true; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "lock", "test"]) }
            }
        }
    }
}
