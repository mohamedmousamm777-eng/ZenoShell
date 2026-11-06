#!/bin/sh
# Prints, one per line, the outputs (monitors) that a window covers completely, for example a
# fullscreen video or game on the active workspace. The animated wallpaper pauses there.
# niri: a window as big as the output. Hyprland: the active workspace has a fullscreen window.
if [ -n "$NIRI_SOCKET" ]; then
    outs=$(niri msg --json outputs 2>/dev/null) || exit 0
    wss=$(niri msg --json workspaces 2>/dev/null) || exit 0
    wins=$(niri msg --json windows 2>/dev/null) || exit 0
    jq -rn --argjson o "$outs" --argjson s "$wss" --argjson w "$wins" '
        $s[] | select(.is_active and .output != null) | . as $ws
        | ($o[$ws.output].logical // empty) as $l
        | select(any($w[];
            .workspace_id == $ws.id
            and (.layout.window_size[0] >= ($l.width - 4))
            and (.layout.window_size[1] >= ($l.height - 4))))
        | $ws.output' 2>/dev/null
elif [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    mons=$(hyprctl monitors -j 2>/dev/null) || exit 0
    wss=$(hyprctl workspaces -j 2>/dev/null) || exit 0
    jq -rn --argjson m "$mons" --argjson w "$wss" '
        $m[] | . as $mo
        | select(any($w[]; .id == $mo.activeWorkspace.id and .hasfullscreen))
        | .name' 2>/dev/null
fi
exit 0
