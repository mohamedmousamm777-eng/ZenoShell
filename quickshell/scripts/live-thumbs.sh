#!/bin/sh
# Still frame (jpg) of every video / GIF in a folder (or of a single file), made with ffmpeg:
#   ~/.cache/quickshell-live/thumbs/<file name>.jpg
# Prints the file name of each one that is ready (new or already there).
# The picker shows them, pywal takes the colors from them, awww and the lock screen use them as the still wallpaper.
out="$HOME/.cache/quickshell-live/thumbs"
mkdir -p "$out"

one() {
    f="$1"
    [ -f "$f" ] || return
    command -v ffmpeg >/dev/null 2>&1 || return      # without ffmpeg: no frames (GIFs are shown by the picker itself)
    name=$(basename "$f")
    th="$out/$name.jpg"
    if [ ! -s "$th" ] || [ "$f" -nt "$th" ]; then
        # a second in, to skip black intros; very short clips fall back to the first frame
        ffmpeg -v error -y -ss 1 -i "$f" -frames:v 1 -vf "scale=1600:-2" -q:v 3 "$th" 2>/dev/null
        [ -s "$th" ] || ffmpeg -v error -y -i "$f" -frames:v 1 -vf "scale=1600:-2" -q:v 3 "$th" 2>/dev/null
    fi
    [ -s "$th" ] && printf '%s\n' "$name"
}

if [ -d "$1" ]; then
    for f in "$1"/*; do
        [ -f "$f" ] || continue
        # the extension in any case (.gif, .GIF, .Gif ...)
        case $(printf '%s' "${f##*.}" | tr 'A-Z' 'a-z') in
            mp4|webm|mkv|mov|gif) one "$f" ;;
        esac
    done
else
    one "$1"
fi
exit 0
