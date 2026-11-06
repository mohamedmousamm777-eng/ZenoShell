#!/bin/sh
# Prints the wallpapers folder: <Pictures>/Wallpapers, where <Pictures> is the system one
# (Pictures, Immagini, Bilder...). Override with QS_WALLPAPERS=/some/folder.
# With the argument "video" it prints the folder of the animated wallpapers instead:
# <Pictures>/Wallpapers_Video, next to the first one (override: QS_WALLPAPERS_VIDEO=/some/folder).
if [ "$1" = video ]; then
    [ -n "$QS_WALLPAPERS_VIDEO" ] && { printf '%s\n' "$QS_WALLPAPERS_VIDEO"; exit 0; }
    d=$(sh "$0")
    printf '%s/Wallpapers_Video\n' "$(dirname "$d")"
    exit 0
fi
if [ -n "$QS_WALLPAPERS" ]; then printf '%s\n' "$QS_WALLPAPERS"; exit 0; fi
pics=""
command -v xdg-user-dir >/dev/null 2>&1 && pics=$(xdg-user-dir PICTURES 2>/dev/null)
case "$pics" in ""|"$HOME"|"$HOME/") pics="$HOME/Pictures" ;; esac
printf '%s/Wallpapers\n' "$pics"
