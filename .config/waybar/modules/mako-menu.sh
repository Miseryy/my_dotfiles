#!/bin/bash

# This script sends a USR1 signal to deadd-notification-center
# to trigger its notification center/history window.

# Find the PID of deadd-notification-center
PID=$(pidof deadd-notification-center)

if [[ -z "$PID" ]]; then
  notify-send "エラー" "deadd-notification-centerが実行されていません。"
else
  # Send the USR1 signal to the deadd-notification-center process
  kill -s USR1 "$PID"
fi