#!/usr/bin/env bash

set -u

readonly DISPLAY_SECONDS=3

# /proc/statの累積値を読み、前回との差分からCPU使用率を計算する。
read_cpu_times() {
    local cpu user nice system idle iowait irq softirq steal

    read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    CPU_IDLE=$((idle + iowait))
    CPU_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
}

read_temperature() {
    # thermal_zoneを優先し、見つからなければ主要CPUのhwmonへフォールバックする。
    local zone type hwmon name input label

    for zone in /sys/class/thermal/thermal_zone*; do
        [[ -r "$zone/type" && -r "$zone/temp" ]] || continue
        read -r type < "$zone/type"
        case "$type" in
            x86_pkg_temp|cpu_thermal|soc_thermal)
                cat "$zone/temp"
                return 0
                ;;
        esac
    done

    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ -r "$hwmon/name" ]] || continue
        read -r name < "$hwmon/name"
        case "$name" in
            coretemp|k10temp|zenpower)
                for input in "$hwmon"/temp*_input; do
                    [[ -r "$input" ]] || continue
                    label="${input%_input}_label"
                    if [[ -r "$label" ]]; then
                        read -r label < "$label"
                        case "$label" in
                            "Package id "*|Tctl|Tdie)
                                cat "$input"
                                return 0
                                ;;
                        esac
                    fi
                done

                for input in "$hwmon"/temp*_input; do
                    [[ -r "$input" ]] || continue
                    cat "$input"
                    return 0
                done
                ;;
        esac
    done

    return 1
}

update_cpu() {
    local previous_idle=$CPU_IDLE previous_total=$CPU_TOTAL idle_delta total_delta usage

    read_cpu_times
    idle_delta=$((CPU_IDLE - previous_idle))
    total_delta=$((CPU_TOTAL - previous_total))
    if ((total_delta > 0)); then
        usage=$(((100 * (total_delta - idle_delta) + total_delta / 2) / total_delta))
    else
        usage=0
    fi

    CPU_USAGE=$usage
}

update_temperature() {
    local raw_temperature temperature class

    if ! raw_temperature="$(read_temperature)" || [[ ! "$raw_temperature" =~ ^-?[0-9]+$ ]]; then
        CPU_TEMPERATURE="N/A"
        TEMPERATURE_CLASS="temperature-unavailable"
        return
    fi

    if ((raw_temperature > 1000)); then
        temperature=$(((raw_temperature + 500) / 1000))
    else
        temperature=$raw_temperature
    fi

    class="temperature"
    if ((temperature >= 90)); then
        class="temperature-critical"
    elif ((temperature >= 80)); then
        class="temperature-warning"
    fi

    CPU_TEMPERATURE="${temperature}°C"
    TEMPERATURE_CLASS=$class
}

update_memory() {
    # キャッシュを考慮したMemAvailableを使って実使用率を求める。
    local total available used_percent

    total=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
    available=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
    if [[ "$total" =~ ^[0-9]+$ && "$available" =~ ^[0-9]+$ && $total -gt 0 ]]; then
        used_percent=$(((100 * (total - available) + total / 2) / total))
        MEMORY_USAGE="${used_percent}%"
    else
        MEMORY_USAGE="N/A"
    fi
}

update_stats() {
    update_cpu
    update_temperature
    update_memory
}

show_stat() {
    # CPU使用率、温度、メモリを3秒ずつ順番にバーへ流す。
    local stat=$1 text class

    case "$stat" in
        cpu)
            text="⧯ Cpu: ${CPU_USAGE}%"
            class="cpu"
            ;;
        temperature)
            text=" CPU: ${CPU_TEMPERATURE}"
            class=$TEMPERATURE_CLASS
            ;;
        memory)
            text="󰍛  Mem: ${MEMORY_USAGE}"
            class="memory"
            ;;
    esac

    printf '{"text":"%s","tooltip":"CPU usage: %s%%\\nCPU temperature: %s\\nMemory usage: %s","class":"%s"}\n' \
        "$text" "$CPU_USAGE" "$CPU_TEMPERATURE" "$MEMORY_USAGE" "$class"
}

read_cpu_times
sleep 0.2

while true; do
    update_stats
    show_stat cpu
    sleep "$DISPLAY_SECONDS"
    update_stats
    show_stat temperature
    sleep "$DISPLAY_SECONDS"
    update_stats
    show_stat memory
    sleep "$DISPLAY_SECONDS"
done
