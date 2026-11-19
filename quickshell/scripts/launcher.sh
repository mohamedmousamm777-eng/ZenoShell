#!/bin/sh
# usage: launcher.sh files <text> | windows | focus <id>
case "$1" in
files)
    q="$2"
    [ -n "$q" ] || exit 0
    if command -v fd >/dev/null 2>&1; then
        fd --fixed-strings --ignore-case --absolute-path --max-results 30 -- "$q" "$HOME" 2>/dev/null
    else
        find "$HOME" -maxdepth 6 -name '.?*' -prune -o -iname "*$q*" -print 2>/dev/null | head -n 30
    fi
    ;;
windows)
    if [ -n "$NIRI_SOCKET" ]; then
        niri msg --json windows 2>/dev/null \
            | jq -r '.[] | [(.id|tostring), (.app_id // ""), (.title // "")] | @tsv' 2>/dev/null
    else
        hyprctl -j clients 2>/dev/null \
            | jq -r '.[] | select(.mapped != false) | [.address, .class, .title] | @tsv' 2>/dev/null
    fi
    ;;
focus)
    [ -n "$2" ] || exit 1
    if [ -n "$NIRI_SOCKET" ]; then
        niri msg action focus-window --id "$2"
    else
        hyprctl dispatch focuswindow "address:$2"
    fi
    ;;
esac
