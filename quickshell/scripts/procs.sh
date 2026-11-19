#!/bin/sh
# Busiest processes right now: "pid<TAB>cpu<TAB>mem<TAB>name" per line, at most 40 (read by services/SysStats.qml).
# top is run twice: the first screen only shows averages since the start, the second one the last moments.
# CPU is per logical core (it can pass 100); the shell divides it by the number of cores.
export LC_ALL=C
top -b -n 2 -d 0.7 -w 200 -o %CPU 2>/dev/null | awk '
    /^top -/ { blk++ }
    blk == 2 && /^ *[0-9]+ / { printf "%s\t%s\t%s\t%s\n", $1, $9, $10, $12 }' | head -n 40
