#!/bin/sh
# usage: maptiles.sh <style/z/x/y> ...      (style: light or dark)
# Downloads map tiles (CARTO / OpenStreetMap) into the local cache and prints the ones that are ready.
# Only runs when the weather panel asks for tiles, and only after the user allowed internet access.
base="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-weather/tiles"
ua="ZenoShell-Weather/1.0 (+https://github.com/mohamedmousamm777-eng/ZenoShell)"

for key in "$@"; do
    case "$key" in
        light/[0-9]*/[0-9]*/[0-9]*|dark/[0-9]*/[0-9]*/[0-9]*) ;;
        *) continue ;;
    esac
    f="$base/$key.png"
    if [ -s "$f" ]; then
        echo "$key"
        continue
    fi
    mkdir -p "$(dirname "$f")"
    style=${key%%/*}; rest=${key#*/}; z=${rest%%/*}; rest=${rest#*/}; x=${rest%%/*}; y=${rest#*/}
    if curl -fsS --max-time 15 -A "$ua" -o "$f.part" "https://a.basemaps.cartocdn.com/${style}_all/$z/$x/$y@2x.png" 2>/dev/null && [ -s "$f.part" ]; then
        mv "$f.part" "$f"
        echo "$key"
    else
        rm -f "$f.part"
    fi
done

# Old tiles are removed (not used for 30 days)
[ -d "$base" ] && find "$base" -type f -atime +30 -delete 2>/dev/null
exit 0
