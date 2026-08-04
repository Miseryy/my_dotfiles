#!/usr/bin/env bash

set -u

# バイト毎秒をバーで読みやすい単位へ変換する。
format_rate() {
    local bytes=$1

    if (( bytes >= 1048576 )); then
        awk -v value="$bytes" 'BEGIN { printf "%.1f MiB/s", value / 1048576 }'
    elif (( bytes >= 1024 )); then
        awk -v value="$bytes" 'BEGIN { printf "%.1f KiB/s", value / 1024 }'
    else
        printf '%d B/s' "$bytes"
    fi
}

read_totals() {
    # /proc/net/devから対象インターフェースの累積送受信量を読む。
    local interface=$1
    awk -v interface="$interface" '
        $1 == interface ":" { print $2, $10; found = 1 }
        END { if (!found) print "0 0" }
    ' /proc/net/dev
}

previous_interface=""
previous_rx=0
previous_tx=0

while true; do
    # デフォルトルートを持つNICを現在利用中の接続として扱う。
    interface=$(awk '$2 == "00000000" && $4 == "0003" { print $1; exit }' /proc/net/route)
    if [[ -z "$interface" ]]; then
        printf '{"interface":"","address":"","download":"0 B/s","upload":"0 B/s"}\n'
        sleep 2
        continue
    fi

    address=$(ip -4 -o address show dev "$interface" scope global 2>/dev/null | awk 'NR == 1 { split($4, value, "/"); print value[1] }')
    read -r current_rx current_tx < <(read_totals "$interface")
    if [[ "$interface" != "$previous_interface" ]]; then
        previous_rx=$current_rx
        previous_tx=$current_tx
    fi

    # 2秒間の差分を1秒あたりの速度へ換算する。
    rx_rate=$(( (current_rx - previous_rx) / 2 ))
    tx_rate=$(( (current_tx - previous_tx) / 2 ))
    (( rx_rate < 0 )) && rx_rate=0
    (( tx_rate < 0 )) && tx_rate=0

    printf '{"interface":"%s","address":"%s","download":"%s","upload":"%s"}\n' \
        "$interface" "$address" "$(format_rate "$rx_rate")" "$(format_rate "$tx_rate")"

    previous_interface=$interface
    previous_rx=$current_rx
    previous_tx=$current_tx
    sleep 2
done
