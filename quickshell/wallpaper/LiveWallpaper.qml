import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Draws the animated wallpaper (video or GIF) on every monitor, with Qt only (no mpvpaper).
// It sits on the Bottom layer: above the still wallpaper that awww draws, below the windows.
// Muted always. State and pause rules: services/LiveWall.qml.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            readonly property bool paused: LiveWall.pausedOn(modelData.name)

            visible: LiveWall.wanted
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}                     // clicks go through

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "shell-live-wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Loaders: when it is off, the decoder is released
            Loader {
                id: gifLoader
                anchors.fill: parent
                active: win.visible && LiveWall.isGif
                sourceComponent: AnimatedImage {
                    source: LiveWall.url
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false                // do not keep every frame in memory
                    playing: true
                    paused: win.paused
                }
            }

            // Video: loaded from a file, so a missing Qt Multimedia does not break the shell
            Loader {
                id: videoLoader
                anchors.fill: parent
                active: win.visible && !LiveWall.isGif
                source: "VideoLayer.qml"

                onStatusChanged: {
                    if (status === Loader.Error) LiveWall.videoMissing = true
                    else if (status === Loader.Ready) LiveWall.videoMissing = false
                }
                onLoaded: {
                    item.source = Qt.binding(() => LiveWall.url)
                    item.paused = Qt.binding(() => win.paused)
                }
            }
        }
    }
}
