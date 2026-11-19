import QtQuick
import Quickshell
import qs.bar
import qs.osd
import qs.launcher
import qs.wallpaper
import qs.ipc
import qs.lock
import qs.sysmon
import qs.widgets
import qs.hello
import qs.settings
import qs.classicbar
import qs.welcome
import qs.weather
import qs.services

ShellRoot {
    // Singletons start the first time something uses them. Pages are now created only when opened,
    // so the ones that restore a saved state at startup are touched here, once.
    QtObject {
        property var touched: [NightLight.on, AudioFx.enabled]
    }

    Bar {}
    Osd {}
    LauncherIpc {}
    WallpaperPicker {}
    LiveWallpaper {}
    ShellIpc {}
    LockScreen {}
    SysPill {}
    Hello {}
    StylePicker {}
    Identify {}
    SettingsWindow {}
    WelcomeWindow {}
    WeatherWindow {}
    Dock {}
    IdleWatcher {}
}
