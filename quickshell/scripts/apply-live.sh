#!/bin/sh
# Applies an animated wallpaper (video or GIF).
# The shell plays it by itself (services/LiveWall.qml); here we set a still frame as the normal
# wallpaper (awww, pywal colors, blur, lock screen) and remember which file is playing.
# The frame has the size of the video (not the small picker thumbnail), so the still wallpaper
# looks sharp when the animation is off or while it starts.
f="$1"
[ -f "$f" ] || exit 1
here=$(dirname "$0")
shelldir=$(cd "$here/.." && pwd)
cache="$HOME/.cache/quickshell-live"
th="$cache/thumbs/$(basename "$f").jpg"

sh "$here/live-thumbs.sh" "$f" >/dev/null       # the picker thumbnail (also a fallback)
[ -s "$th" ] || exit 1

# full-size frame; one file per video, so awww and the restore at login always find it
key=$(printf '%s' "$f" | md5sum | cut -d' ' -f1)
frame="$cache/frames/$key.jpg"
mkdir -p "$cache/frames"
if [ ! -s "$frame" ] || [ "$f" -nt "$frame" ]; then
    ffmpeg -v error -y -ss 1 -i "$f" -frames:v 1 -q:v 2 "$frame" 2>/dev/null
    [ -s "$frame" ] || ffmpeg -v error -y -i "$f" -frames:v 1 -q:v 2 "$frame" 2>/dev/null
fi
[ -s "$frame" ] || frame="$th"

printf '%s' "$f" > "$HOME/.cache/quickshell-live-current"
qs -p "$shelldir" ipc call livewall reload >/dev/null 2>&1     # the video starts right away
QS_KEEP_LIVE=1 sh "$here/apply-wallpaper.sh" "$frame"
