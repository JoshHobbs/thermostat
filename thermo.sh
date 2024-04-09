#!/bin/bash

# Load configuration
. /path/to/config.sh

# LAN interface (usually eth0 or wlan0)
INTERFACE="wlan0"
# File to save the last seen timestamp
LAST_SEEN_FILE="last_seen.txt"
STATUS_FILE="status.txt"

# Ensure the LAST_SEEN_FILE path is correctly set to a writable location

# Function to send notification
send_notification() {
    # Check if the last seen file exists and read the last seen time
    if [ -f "$LAST_SEEN_FILE" ]; then
        LAST_SEEN=$(cat "$LAST_SEEN_FILE")
        MESSAGE="Thermostat is disconnected. Last seen: $LAST_SEEN"
    else
        MESSAGE="Thermostat is disconnected. No last seen record available."
    fi
    echo "$MESSAGE" | curl -d "$MESSAGE" ntfy.sh/$NTFY_TOPIC
    echo "Disconnected" > "$STATUS_FILE"
}

# Function to update last seen file
update_last_seen() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$LAST_SEEN_FILE"
    # Send a notification if the thermostat was previously disconnected
    if [ -f "$STATUS_FILE" ]; then
        if [ "$(cat "$STATUS_FILE")" = "Disconnected" ]; then
            curl -d "Thermostat is reconnected." ntfy.sh/$NTFY_TOPIC
        fi
    fi
    echo "Connected" > "$STATUS_FILE"
}


# Initial scan for the thermostat's MAC address
SCAN_RESULT=$(arp-scan --interface=$INTERFACE --localnet 2>&1) # Capture stderr to diagnose permission issues

# Check for MAC/Vendor file permission warnings
if echo "$SCAN_RESULT" | grep -q "Cannot open MAC/Vendor file"; then
    echo "Warning: arp-scan cannot open MAC/Vendor files. Check file permissions or run as root."
fi

# Proceed with checking for the thermostat's MAC address
if echo "$SCAN_RESULT" | grep -q "$THERMOSTAT_MAC"; then
    echo "Thermostat is connected."
    update_last_seen
else

    attempt_count=0
    while [ $attempt_count -lt 18 ]; do
        echo "Thermostat is disconnected. Rescanning in 30 seconds..."
        ((attempt_count++))
        sleep 30 # Wait for 30 seconds before rescanning
        # Rescan the network for the thermostat's MAC address
        if arp-scan --interface=$INTERFACE --localnet | grep -q "$THERMOSTAT_MAC"; then
            echo "Thermostat is reconnected."
            update_last_seen
            break
        fi
        send_notification
    done
fi
