#!/bin/bash

# Configuration file
CONFIG_FILE="/home/owner/.config/swaync/config.json"

# --- Step 1: Find Connected Audio Device Name ---
# Extract name from sinks (usually what the user sees)
NAME=$(wpctl status | grep -i "Shokz" | head -n 1 | sed -E 's/.*\. (.*) \[.*/\1/' | sed 's/^[│ ]*//' | xargs)

if [ -z "$NAME" ]; then
    NAME=$(wpctl status | grep "Sinks:" -A 10 | grep -E "[0-9]+\." | grep -ivE "Analog|HDMI|Controller" | head -n 1 | sed -E 's/.*\. (.*) \[.*/\1/' | xargs)
fi

# --- Step 2: Get MAC address from wpctl output directly ---
# Look for the bluetooth device ID in any part of wpctl status
MAC=$(wpctl status | grep -E "bluez_.*([0-9A-F]{2}:){5}[0-9A-F]{2}" -o | head -n 1 | grep -oE "([0-9A-F]{2}:){5}[0-9A-F]{2}" | tr '_' ':')

# If MAC is empty, try to get it from bluetoothctl as fallback
if [ -z "$MAC" ] && [ -n "$NAME" ]; then
    MAC=$(bluetoothctl devices | grep -i "$NAME" | awk '{print $2}' | head -n 1)
fi

# --- Step 3: Get Battery Percentage (DBus is best) ---
BATTERY=""
if [ -n "$MAC" ]; then
    # Direct DBus query
    # The path is usually /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF
    DBUS_OBJ="/org/bluez/hci0/dev_$(echo "$MAC" | tr ':' '_')"
    BATTERY=$(dbus-send --system --dest=org.bluez --print-reply "$DBUS_OBJ" org.freedesktop.DBus.Properties.Get string:"org.bluez.Battery1" string:"Percentage" 2>/dev/null | grep "variant" | awk '{print $NF}')
fi

# --- Step 4: Format Label ---
if [ -n "$NAME" ]; then
    if [ -n "$BATTERY" ]; then
        LABEL=" $NAME ($BATTERY%)"
    else
        LABEL=" $NAME"
    fi
else
    # Check if bluetooth is actually powered on
    if bluetoothctl show | grep -q "Powered: yes"; then
        LABEL=" Bluetooth"
    else
        LABEL=" Off"
    fi
fi

# --- Step 5: Update SwayNC config.json AND Reload ---
if [ -f "$CONFIG_FILE" ]; then
    # Update both buttons-grid#bt-status and label#bt-status just in case
    jq --arg label "$LABEL" '
        (.["widget-config"]["buttons-grid#bt-status"].actions[0].label) = $label |
        (.["widget-config"]["label#bt-status"].text) = $label
    ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    # Force swaync to reload config and CSS
    swaync-client -R
    swaync-client -rs
fi

echo "$LABEL"
