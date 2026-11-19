# ZenoShell 1.2.0

The biggest update so far: animated wallpapers, a real Audio Center, a System Monitor, a weather panel with a real map, a unified launcher, three new looks for the Classic bar, profile and lock screen styles, and about half the memory use.

> Made for niri and Hyprland on Arch Linux. Tested there; anything else, you are the tester.

## What's new

### Animated wallpapers
- Videos and GIFs play inside the shell (Qt Multimedia, always muted), one player per monitor, above the fixed wallpaper.
- `Alt+Shift+W` picks one, `Alt+W` or **Stop** in Settings stops it. The still frame is the normal wallpaper and the base for the pywal colors.
- **Smart pause**: stops decoding with a fullscreen window, on the lock screen, with the screen off, in Game Mode and Eco Mode, and when the PC is under load (CPU > 85% or RAM > 90%). Switch in Settings.
- Needs `qt6-multimedia-ffmpeg` for video. Without it the shell still starts and GIFs work.

### Audio Center (`Alt+A`, `Alt+Shift+A`)
- System-wide equalizer on a PipeWire filter chain, with presets and left/right balance.
- Four looks, one for each bar style. The curve runs over the pills, with knobs you can click and drag.
- A blurred music strip sits above the equalizer.

### System Monitor (`Alt+M`)
- Six tiles (CPU, RAM, GPU, temperature, processes, network) and six detail views.
- Reads **every** graphics chip, including the one built into the CPU.
- Only reads while it is open, and closes only with a click outside.

### Weather and map (`Alt+Shift+M`)
- Real map (OpenStreetMap / CARTO tiles) with weather layers, forecast and air quality from Open-Meteo.
- Asks for permission before using your location. Settings page: on/off, place, units and language, map source and refresh.

### Launcher
- One single list: apps, files (`/`), open windows (`w`), clipboard (`c`), emoji (`:`), commands (`>`), a calculator, unit conversion and web search (`g`, `ddg`, `yt`, `gh`, `wp`, `mp`).

### Classic bar: three new looks (`Alt+V`)
- **Full**: transparent bar, stats, window title, a notch with the workspaces in kanji, tray and battery.
- **Capsules**: colored capsules in dark containers.
- **Floating + dock**: separate rounded boxes and a dock with your favorite and open apps.
- Colors follow your pywal theme. Open apps and tray icons are shown.

### Profile and lock screen
- New first page in Settings: **Profile & lock screen**. Name, place, photo shape and a small selector with a circle for each photo in `~/Immagini/Profile`.
- Three lock styles: **Classic**, **Giant clock** (a lock pill that fills with dots) and **Terminal**.
- You can move the clock and the login field to any of nine positions. A safe **Test lock** button unlocks by itself after 12 seconds.

### Memory and stability
- About half the RAM: pages and panels are created only when you open them and freed a minute after (about 251 MB to 138 MB of private memory in our tests).
- The shell starts with `qs -n`, so a second copy can never start by mistake.
- Night light fixed: it restores its state at start and stops leftover `gammastep` processes.

## Shortcuts added
`Alt+A` Audio Center · `Alt+Shift+A` equalizer · `Alt+M` System Monitor · `Alt+Shift+M` weather · `Alt+V` Classic look / Dashboard version · `Alt+Shift+W` animated wallpaper · `Alt+O` Settings

## Update
```
cd quickshell-dots && git pull
```
then run the installer again, or copy the `quickshell`, `niri` and `hypr` folders by hand, and restart with `qs kill; sleep 2; qs -n -d`.
