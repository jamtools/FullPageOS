#!/bin/bash
# Backlight dimmer daemon - monitors user activity and dims/turns off backlight after inactivity
# This provides hardware-level backlight control that works when DPMS doesn't

# Configuration
IDLE_TIMEOUT=600  # 10 minutes in seconds
CHECK_INTERVAL=5  # Check every 5 seconds

# Backlight paths (automatically detect the correct one)
BACKLIGHT_PATH=""
for path in /sys/class/backlight/*/brightness; do
    if [ -e "$path" ]; then
        BACKLIGHT_PATH=$(dirname "$path")
        break
    fi
done

if [ -z "$BACKLIGHT_PATH" ]; then
    echo "Error: No backlight device found in /sys/class/backlight/"
    exit 1
fi

BRIGHTNESS_FILE="$BACKLIGHT_PATH/brightness"
MAX_BRIGHTNESS_FILE="$BACKLIGHT_PATH/max_brightness"
ACTUAL_BRIGHTNESS_FILE="$BACKLIGHT_PATH/actual_brightness"

# Get maximum brightness value
MAX_BRIGHTNESS=$(cat "$MAX_BRIGHTNESS_FILE")
echo "Backlight device: $BACKLIGHT_PATH"
echo "Maximum brightness: $MAX_BRIGHTNESS"

# State tracking
STATE="on"  # on, dimmed, off
SAVED_BRIGHTNESS=""

# Function to get current brightness
get_brightness() {
    cat "$BRIGHTNESS_FILE"
}

# Function to set brightness
set_brightness() {
    local value=$1
    echo "$value" > "$BRIGHTNESS_FILE"
}

# Function to get idle time in milliseconds
get_idle_time() {
    # Use xprintidle if available, otherwise use xssstate
    if command -v xprintidle &> /dev/null; then
        xprintidle
    else
        # Fallback: parse xset output
        local idle_time=$(xset q | grep timeout | awk '{print $2}')
        echo $((idle_time * 1000))
    fi
}

# Function to turn backlight off
backlight_off() {
    if [ "$STATE" != "off" ]; then
        SAVED_BRIGHTNESS=$(get_brightness)
        set_brightness 0
        STATE="off"
        echo "$(date): Backlight OFF (was $SAVED_BRIGHTNESS)"
    fi
}

# Function to turn backlight on
backlight_on() {
    if [ "$STATE" != "on" ]; then
        if [ -n "$SAVED_BRIGHTNESS" ] && [ "$SAVED_BRIGHTNESS" -gt 0 ]; then
            set_brightness "$SAVED_BRIGHTNESS"
        else
            set_brightness "$MAX_BRIGHTNESS"
        fi
        STATE="on"
        echo "$(date): Backlight ON (brightness: $(get_brightness))"
    fi
}

# Set up X display if not set
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi

# Install xprintidle if not present (for better idle detection)
if ! command -v xprintidle &> /dev/null; then
    echo "Warning: xprintidle not found. Using xset for idle detection (less accurate)"
fi

# Main monitoring loop
echo "Starting backlight dimmer daemon..."
echo "Idle timeout: ${IDLE_TIMEOUT}s"
echo "Check interval: ${CHECK_INTERVAL}s"

while true; do
    # Get idle time in milliseconds
    IDLE_MS=$(get_idle_time)
    IDLE_SECONDS=$((IDLE_MS / 1000))

    if [ "$IDLE_SECONDS" -ge "$IDLE_TIMEOUT" ]; then
        # User has been idle long enough - turn off backlight
        backlight_off
    else
        # User is active - ensure backlight is on
        backlight_on
    fi

    sleep "$CHECK_INTERVAL"
done
