#!/bin/bash
# Backlight dimmer daemon - monitors user activity and dims/turns off backlight after inactivity
# This provides hardware-level backlight control that works when DPMS doesn't

# Configuration
DIM_TIMEOUT=600    # Time until dim (10 minutes)
OFF_TIMEOUT=900    # Time until off (15 minutes total: 10min + 5min)
CHECK_INTERVAL=5   # Check every 5 seconds
DIM_BRIGHTNESS_PERCENT=25  # Dim to 25% of max brightness
MIN_BRIGHTNESS=0   # Minimum brightness level (0 = off)

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
DIM_BRIGHTNESS=$((MAX_BRIGHTNESS * DIM_BRIGHTNESS_PERCENT / 100))
echo "Backlight device: $BACKLIGHT_PATH"
echo "Maximum brightness: $MAX_BRIGHTNESS"
echo "Dim brightness (${DIM_BRIGHTNESS_PERCENT}%): $DIM_BRIGHTNESS"

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

# Timestamp file used by input monitor
TIMESTAMP_FILE="/tmp/last_input_activity"

# Function to get idle time in milliseconds
get_idle_time() {
    local current_time_ms=$(date +%s%3N)
    local input_idle=999999999

    # Read last input activity timestamp from file (written by Python monitor)
    if [ -f "$TIMESTAMP_FILE" ]; then
        local last_activity=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo 0)
        if [ "$last_activity" -gt 0 ]; then
            input_idle=$((current_time_ms - last_activity))
        fi
    fi

    # Also check X11 idle time for non-touch input (keyboard, mouse via X)
    local x_idle=999999999
    if command -v xprintidle &> /dev/null; then
        x_idle=$(xprintidle 2>/dev/null || echo 999999999)
    fi

    # Return the minimum idle time (most recent activity)
    if [ "$x_idle" -lt "$input_idle" ]; then
        echo "$x_idle"
    else
        echo "$input_idle"
    fi
}

# Function to set backlight to dim state
backlight_to_dim() {
    if [ "$STATE" = "on" ]; then
        SAVED_BRIGHTNESS=$(get_brightness)
        set_brightness "$DIM_BRIGHTNESS"
        STATE="dimmed"
        echo "$(date): Backlight dimmed to ${DIM_BRIGHTNESS_PERCENT}% ($DIM_BRIGHTNESS) - was $SAVED_BRIGHTNESS"
    fi
}

# Function to turn backlight off
backlight_to_off() {
    if [ "$STATE" != "off" ]; then
        # Save current brightness if not already saved
        if [ -z "$SAVED_BRIGHTNESS" ]; then
            SAVED_BRIGHTNESS=$(get_brightness)
        fi

        set_brightness "$MIN_BRIGHTNESS"
        STATE="off"

        # Block touch input to prevent ghost touches during wake-up
        block_touch_input

        echo "$(date): Backlight OFF - was at brightness $SAVED_BRIGHTNESS"
    fi
}

# Function to restore backlight to full brightness
backlight_to_on() {
    if [ "$STATE" != "on" ]; then
        local target_brightness
        if [ -n "$SAVED_BRIGHTNESS" ] && [ "$SAVED_BRIGHTNESS" -gt 0 ]; then
            target_brightness="$SAVED_BRIGHTNESS"
        else
            target_brightness="$MAX_BRIGHTNESS"
        fi

        set_brightness "$target_brightness"
        STATE="on"

        # Unblock touch input if it was blocked
        unblock_touch_input

        echo "$(date): Backlight ON - restored to $target_brightness"
    fi
}

# Function to block touch input (prevent ghost touches)
block_touch_input() {
    # Find and disable touchscreen input devices
    for device_id in $(xinput list --id-only 2>/dev/null); do
        local device_name=$(xinput list --name-only "$device_id" 2>/dev/null)
        if echo "$device_name" | grep -iq "touch\|ft5406"; then
            xinput disable "$device_id" 2>/dev/null
            echo "$(date): Disabled touch input device: $device_name (ID: $device_id)"
        fi
    done
}

# Function to unblock touch input
unblock_touch_input() {
    # Find and enable touchscreen input devices
    for device_id in $(xinput list --id-only 2>/dev/null); do
        local device_name=$(xinput list --name-only "$device_id" 2>/dev/null)
        if echo "$device_name" | grep -iq "touch\|ft5406"; then
            xinput enable "$device_id" 2>/dev/null
            echo "$(date): Enabled touch input device: $device_name (ID: $device_id)"
        fi
    done
}

# Set up X display if not set
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi

# Install xprintidle if not present (for better idle detection)
if ! command -v xprintidle &> /dev/null; then
    echo "Warning: xprintidle not found. Using xset for idle detection (less accurate)"
fi

# Start Python-based input event monitor in background
MONITOR_SCRIPT="/custom_scripts/input-activity-monitor.py"
if [ -f "$MONITOR_SCRIPT" ]; then
    python3 "$MONITOR_SCRIPT" &
    INPUT_MONITOR_PID=$!
    echo "Started input event monitor (PID: $INPUT_MONITOR_PID)"

    # Trap to clean up background process on exit
    trap "kill $INPUT_MONITOR_PID 2>/dev/null" EXIT

    # Give the monitor a moment to initialize
    sleep 1
else
    echo "Warning: Input activity monitor not found at $MONITOR_SCRIPT"
    echo "Falling back to X11-only idle detection"
fi

# Main monitoring loop
echo "Starting backlight dimmer daemon..."
echo "Stage 1 (Full brightness): Always on when active"
echo "Stage 2 (Dim to ${DIM_BRIGHTNESS_PERCENT}%): After ${DIM_TIMEOUT}s idle"
echo "Stage 3 (Off): After ${OFF_TIMEOUT}s idle"
echo "Check interval: ${CHECK_INTERVAL}s"

while true; do
    # Get idle time in milliseconds
    IDLE_MS=$(get_idle_time)
    IDLE_SECONDS=$((IDLE_MS / 1000))

    if [ "$IDLE_SECONDS" -ge "$OFF_TIMEOUT" ]; then
        # Stage 3: Turn off completely
        backlight_to_off
    elif [ "$IDLE_SECONDS" -ge "$DIM_TIMEOUT" ]; then
        # Stage 2: Dim the backlight
        backlight_to_dim
    else
        # Stage 1: Full brightness (user is active)
        backlight_to_on
    fi

    sleep "$CHECK_INTERVAL"
done
