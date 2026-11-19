#!/bin/sh
# Profile photos: the images of ~/Immagini/Profile (the folder is created if it does not exist).
# Prints one file name per line (jpg, jpeg, png, webp, gif in any case), newest first.
dir="${1:-$HOME/Immagini/Profile}"
mkdir -p "$dir" 2>/dev/null
ls -t "$dir" 2>/dev/null | while IFS= read -r f; do
    [ -f "$dir/$f" ] || continue
    case $(printf '%s' "${f##*.}" | tr 'A-Z' 'a-z') in
        jpg|jpeg|png|webp|gif) printf '%s\n' "$f" ;;
    esac
done
