#!/bin/sh
# Equalizer engine of the Audio Center (used by services/AudioFx.qml).
#
#   audiofx.sh gen   <file> <target-sink> <preamp-dB> <balance> <g1> ... <g10>
#        writes a PipeWire filter-chain configuration: a virtual output "ZenoShell EQ" that
#        passes the sound through 10 filters and plays it on <target-sink> (the real output)
#   audiofx.sh apply <preamp-dB> <balance> <g1> ... <g10>
#        changes the gains of the running filter without restarting it (pw-cli); exit 1 if it cannot
#      (balance: -1 = all left ... 0 = centre ... +1 = all right)
#   audiofx.sh node
#        prints the PipeWire id of the virtual output, or nothing if it does not exist
#
# Bands (Hz): 31 63 125 250 500 1k 2k 4k 8k 16k. The first is a low shelf, the last a high shelf.

NAME="zeno_eq_sink"
FREQS="31 63 125 250 500 1000 2000 4000 8000 16000"

# Linear gain from dB
lin() { awk -v d="$1" 'BEGIN { printf "%.6f", exp(log(10) * d / 20) }'; }

# Linear gain of one side: preamp in dB, balance -1..1, side l or r
side() {
    awk -v d="$1" -v b="$2" -v c="$3" 'BEGIN {
        if (b !~ /^-?[0-9]+(\.[0-9]+)?$/) b = 0; if (b > 1) b = 1; if (b < -1) b = -1
        m = exp(log(10) * d / 20)
        if (c == "l" && b > 0) m = m * (1 - b)
        if (c == "r" && b < 0) m = m * (1 + b)
        printf "%.6f", m }'
}

# Keeps a number between -12 and +12 (and drops anything that is not a number)
clampdb() {
    awk -v v="$1" 'BEGIN { if (v !~ /^-?[0-9]+(\.[0-9]+)?$/) v = 0; if (v > 12) v = 12; if (v < -12) v = -12; printf "%.1f", v }'
}

gen() {
    rm -f "${XDG_RUNTIME_DIR:-/tmp}/zeno_eq.id"
    out=$1; target=$2; pre=$(clampdb "$3"); bal=$4; shift 4
    [ -n "$out" ] || exit 2
    # the target is only a node name: no quotes or spaces allowed
    case "$target" in *[!A-Za-z0-9._:-]*|"") target="" ;; esac

    gains=""
    i=0
    for g in "$@"; do
        i=$((i + 1)); [ "$i" -le 10 ] || break
        gains="$gains $(clampdb "$g")"
    done
    while [ "$i" -lt 10 ]; do i=$((i + 1)); gains="$gains 0.0"; done

    tmp="$out.tmp"
    {
        echo '# Written by ZenoShell (scripts/audiofx.sh). Do not edit: it is rebuilt every time.'
        echo 'context.spa-libs = {'
        echo '    audio.convert.* = audioconvert/libspa-audioconvert'
        echo '    support.*       = support/libspa-support'
        echo '}'
        echo 'context.modules = ['
        echo '    { name = libpipewire-module-rt args = { nice.level = -11 } flags = [ ifexists nofail ] }'
        echo '    { name = libpipewire-module-protocol-native }'
        echo '    { name = libpipewire-module-client-node }'
        echo '    { name = libpipewire-module-adapter }'
        echo '    {   name = libpipewire-module-filter-chain'
        echo '        args = {'
        echo '            node.description = "ZenoShell EQ"'
        echo '            media.name       = "ZenoShell EQ"'
        echo '            filter.graph = {'
        echo '                nodes = ['
        for c in l r; do
            echo "                    { type = builtin name = pre_$c label = linear control = { \"Mult\" = $(side "$pre" "$bal" "$c") \"Add\" = 0.0 } }"
            n=0
            for f in $FREQS; do
                n=$((n + 1))
                g=$(echo "$gains" | awk -v k="$n" '{ print $k }')
                if [ "$n" -eq 1 ]; then label=bq_lowshelf
                elif [ "$n" -eq 10 ]; then label=bq_highshelf
                else label=bq_peaking; fi
                echo "                    { type = builtin name = b${n}_$c label = $label control = { \"Freq\" = $f \"Q\" = 1.0 \"Gain\" = $g } }"
            done
        done
        echo '                ]'
        echo '                links = ['
        for c in l r; do
            echo "                    { output = \"pre_$c:Out\" input = \"b1_$c:In\" }"
            n=1
            while [ "$n" -lt 10 ]; do
                echo "                    { output = \"b${n}_$c:Out\" input = \"b$((n + 1))_$c:In\" }"
                n=$((n + 1))
            done
        done
        echo '                ]'
        echo '                inputs  = [ "pre_l:In" "pre_r:In" ]'
        echo '                outputs = [ "b10_l:Out" "b10_r:Out" ]'
        echo '            }'
        echo '            audio.channels = 2'
        echo '            audio.position = [ FL FR ]'
        echo "            capture.props = { node.name = \"$NAME\" media.class = Audio/Sink }"
        if [ -n "$target" ]; then
            echo "            playback.props = { node.name = \"zeno_eq_out\" node.passive = true target.object = \"$target\" stream.dont-remix = true }"
        else
            echo '            playback.props = { node.name = "zeno_eq_out" node.passive = true }'
        fi
        echo '        }'
        echo '    }'
        echo ']'
    } > "$tmp" && mv "$tmp" "$out"
}

node_id() {
    pw-cli ls Node 2>/dev/null | awk -v want="$NAME" '
        /^[ \t]*id [0-9]+,/ { id = $2; sub(",", "", id) }
        /node\.name = / { gsub(/"/, "", $3); if ($3 == want) { print id; exit } }'
}

apply() {
    [ $# -ge 2 ] || exit 1
    cache="${XDG_RUNTIME_DIR:-/tmp}/zeno_eq.id"
    id=$(cat "$cache" 2>/dev/null)
    fresh=0
    if [ -z "$id" ]; then id=$(node_id); fresh=1; fi
    [ -n "$id" ] || exit 1
    # one awk for every number: clamps, balance and linear gains
    params=$(awk -v pre="$1" -v bal="$2" 'BEGIN {
        n = split(ARGV[3], g, " ")
        ARGV[3] = ""
        num = "^-?[0-9]+(\\.[0-9]+)?$"
        if (pre !~ num) pre = 0; if (pre > 12) pre = 12; if (pre < -12) pre = -12
        if (bal !~ num) bal = 0; if (bal > 1) bal = 1; if (bal < -1) bal = -1
        m = exp(log(10) * pre / 20); ml = m; mr = m
        if (bal > 0) ml = m * (1 - bal); if (bal < 0) mr = m * (1 + bal)
        out = sprintf("\"pre_l:Mult\" %.6f \"pre_r:Mult\" %.6f", ml, mr)
        for (i = 1; i <= 10; i++) {
            v = g[i]; if (v !~ num) v = 0; if (v > 12) v = 12; if (v < -12) v = -12
            out = out sprintf(" \"b%d_l:Gain\" %.1f \"b%d_r:Gain\" %.1f", i, v, i, v)
        }
        print out }' "$1" "$2" "$(shift 2; echo "$*")")
    if pw-cli s "$id" Props "{ params = [ $params ] }" >/dev/null 2>&1; then
        [ "$fresh" = 1 ] && echo "$id" > "$cache"
        return 0
    fi
    # the cached id was old: look it up again once
    rm -f "$cache"
    [ "$fresh" = 1 ] && exit 1
    id=$(node_id); [ -n "$id" ] || exit 1
    pw-cli s "$id" Props "{ params = [ $params ] }" >/dev/null 2>&1 || exit 1
    echo "$id" > "$cache"
}

case "$1" in
    gen)   shift; gen "$@" ;;
    apply) shift; apply "$@" ;;
    node)  node_id ;;
    *)     echo "usage: audiofx.sh gen|apply|node ..." >&2; exit 2 ;;
esac
