#!/bin/sh
# System status, one line per entry (read by services/SysStats.qml).
#   sysstats.sh            basic: CPU, RAM, network, disk (the resources pill and the Dashboard)
#   sysstats.sh full       everything above plus frequency, load, sensors, GPU, swap, interfaces (System Monitor, while open)
#   sysstats.sh static     things that never change: CPU model, cores, GPU maker
export LC_ALL=C

head -n1 /proc/stat
awk '/^MemTotal:/{print "memtotal", $2} /^MemAvailable:/{print "memavail", $2}' /proc/meminfo
awk 'NR>2 { gsub(":", " ", $0); if ($1 != "lo") { rx += $2; tx += $10 } } END { print "net", rx, tx }' /proc/net/dev
df -B1 --output=size,used / | tail -n1 | awk '{print "disk", $1, $2}'

if [ "$1" = static ]; then
    awk -F: '/^model name/ { gsub(/^[ \t]+/, "", $2); print "model", $2; exit }' /proc/cpuinfo
    awk '/^cpu cores/ { c = $4 } END { print "cores", (c ? c : 0) }' /proc/cpuinfo
    echo "threads $(nproc --all 2>/dev/null || echo 1)"
    for d in /sys/class/drm/card[0-9]*/device; do
        [ -r "$d/vendor" ] || continue
        case "$(cat "$d/vendor")" in
            0x1002) echo "gpuvendor AMD"; break ;;
            0x10de) echo "gpuvendor NVIDIA"; break ;;
            0x8086) echo "gpuvendor Intel" ;;
        esac
    done
    exit 0
fi

[ "$1" = full ] || exit 0

awk '/^MemFree:/{print "memfree", $2} /^Buffers:/{print "buffers", $2} /^Cached:/{print "cached", $2} /^SwapTotal:/{print "swaptotal", $2} /^SwapFree:/{print "swapfree", $2}' /proc/meminfo
awk 'NR>2 { gsub(":", " ", $0); if ($1 != "lo") print "iface", $1, $2, $10 }' /proc/net/dev
awk '{ split($4, a, "/"); print "load", $1, $2, $3; print "tasks", a[2] }' /proc/loadavg
awk '{print "uptime", int($1)}' /proc/uptime
cat /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq 2>/dev/null | awk '{ s += $1; n++ } END { if (n) print "freq", int(s / n / 1000) }'

# ---- Sensors (hwmon; thermal zones only when hwmon has no temperature) ----
found=0
for h in "${SYSROOT:-}"/sys/class/hwmon/hwmon*; do
    [ -d "$h" ] || continue
    name=$(cat "$h/name" 2>/dev/null)
    for t in "$h"/temp*_input; do
        [ -r "$t" ] || continue
        v=$(cat "$t" 2>/dev/null) || continue
        b=${t%_input}
        l=$(cat "${b}_label" 2>/dev/null)
        [ -n "$l" ] || l=${b##*/}
        echo "temp $v $(printf '%s:%s' "$name" "$l" | tr ' ' '_')"
        found=1
    done
    for f in "$h"/fan*_input; do
        [ -r "$f" ] || continue
        v=$(cat "$f" 2>/dev/null) || continue
        b=${f%_input}
        l=$(cat "${b}_label" 2>/dev/null)
        [ -n "$l" ] || l=${b##*/}
        echo "fan $v $(printf '%s:%s' "$name" "$l" | tr ' ' '_')"
    done
done
if [ "$found" = 0 ]; then
    for z in /sys/class/thermal/thermal_zone*; do
        [ -r "$z/temp" ] || continue
        echo "temp $(cat "$z/temp") $(cat "$z/type" 2>/dev/null | tr ' ' '_')"
    done
fi

# ---- GPUs: every card the kernel shows (the ones inside the CPU too), plus NVIDIA through nvidia-smi ----
#   gpu <n> <maker> <integrated|discrete> <estimated 0|1> <busy %> <video mem used> <video mem total> <MHz> <W> <°C>   (-1 = unknown)
n=0
for c in "${SYSROOT:-}"/sys/class/drm/card[0-9]*; do
    case "${c##*/}" in *-*) continue ;; esac            # card0-HDMI-A-1 and the like are connectors
    d="$c/device"
    [ -r "$d/vendor" ] || continue
    busy=-1; vu=-1; vt=-1; clk=-1; pw=-1; tmp=-1; est=0; kind=discrete
    case "$(cat "$d/vendor")" in
        0x1002)
            maker=AMD
            [ -r "$d/gpu_busy_percent" ] && busy=$(cat "$d/gpu_busy_percent")
            vu=$(cat "$d/mem_info_vram_used" 2>/dev/null || echo -1)
            vt=$(cat "$d/mem_info_vram_total" 2>/dev/null || echo -1)
            # APU (graphics inside the CPU): a small slice of system memory is set aside for it
            [ "$vt" -gt 0 ] 2>/dev/null && [ "$vt" -le 2147483648 ] && kind=integrated
            if [ -r "$d/pp_dpm_sclk" ]; then
                clk=$(awk '/\*/ { gsub(/[Mm][Hh][Zz]/, "", $2); print int($2); exit }' "$d/pp_dpm_sclk")
                [ -n "$clk" ] || clk=-1
            fi
            ;;
        0x8086)
            maker=Intel
            [ -r "$d/lmem_total_bytes" ] || kind=integrated          # Arc cards have their own memory
            act=-1; max=-1
            for f in "$c/gt_act_freq_mhz" "$c/gt/gt0/rps_act_freq_mhz" "$c/gt_cur_freq_mhz"; do
                [ -r "$f" ] && { act=$(cat "$f"); break; }
            done
            for f in "$c/gt_RP0_freq_mhz" "$c/gt/gt0/rps_RP0_freq_mhz" "$c/gt_max_freq_mhz"; do
                [ -r "$f" ] && { max=$(cat "$f"); break; }
            done
            clk=$act
            # Intel does not say how busy the GPU is without root: it is estimated from how fast it runs
            if [ "$act" -ge 0 ] 2>/dev/null && [ "$max" -gt 0 ] 2>/dev/null; then
                busy=$(( act * 100 / max )); [ "$busy" -gt 100 ] && busy=100; est=1
            fi
            ;;
        *) continue ;;                                          # NVIDIA is below; anything else is ignored
    esac
    for hw in "$d"/hwmon/hwmon*; do
        [ -d "$hw" ] || continue
        [ -r "$hw/temp1_input" ] && tmp=$(( $(cat "$hw/temp1_input") / 1000 ))
        [ -r "$hw/freq1_input" ] && clk=$(( $(cat "$hw/freq1_input") / 1000000 ))
        for p in power1_average power1_input; do
            [ -r "$hw/$p" ] && { pw=$(( $(cat "$hw/$p") / 1000000 )); break; }
        done
    done
    [ "$busy" -ge 0 ] 2>/dev/null || [ "$clk" -ge 0 ] 2>/dev/null || continue     # nothing to show
    n=$((n + 1))
    echo "gpu $n $maker $kind $est $busy $vu $vt $clk $pw $tmp"
done
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,clocks.sm,power.draw,temperature.gpu --format=csv,noheader,nounits 2>/dev/null \
        | awk -F', *' -v s="$n" '{ printf "gpu %d NVIDIA discrete 0 %d %d %d %d %d %d\n", s + NR, $1, $2 * 1048576, $3 * 1048576, $4, $5, $6 }'
fi
