pragma Singleton

import Quickshell

Singleton {
    property bool controlOpen: false

    property bool launcherOpen: false
    property string launcherScreen: ""
    property string launcherInitial: ""     // text already typed when the launcher opens by itself

    property bool wallpaperOpen: false
    property string wallpaperScreen: ""
    property bool wallpaperLive: false       // the picker shows the animated wallpapers (Wallpapers_Video)

    property bool powerOpen: false
    property string powerScreen: ""

    property bool captureOpen: false
    property string captureScreen: ""

    // Recording menu (right-click on the pill)
    property bool recMenuOpen: false
    property string recMenuScreen: ""

    // Audio Center (equalizer), opened from the music part or with the shortcut
    property bool audioOpen: false
    property string audioScreen: ""
    function openAudio() { audioScreen = Compositor.focusedMonitor; audioOpen = true }
    function toggleAudio() { if (audioOpen) audioOpen = false; else openAudio() }

    // Lockscreen
    property bool locked: false
    property bool lockTest: false
    property int lockTestLeft: 0
}
