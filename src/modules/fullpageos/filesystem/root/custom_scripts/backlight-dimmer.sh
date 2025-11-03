#!/bin/bash
# Backlight dimmer daemon - monitors user activity and dims/turns off backlight after inactivity
# This provides hardware-level backlight control that works when DPMS doesn't

# Configuration
IDLE_TIMEOUT=600  # 10 minutes in seconds
CHECK_INTERVAL=5  # Check every 5 seconds
DIM_STEPS=10      # Number of steps for progressive dimming
DIM_STEP_DELAY=0.5 # Delay between dimming steps in seconds
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
    local x_idle=999999999
    local touch_idle=999999999

    # Get X11 idle time
    if command -v xprintidle &> /dev/null; then
        x_idle=$(xprintidle 2>/dev/null || echo 999999999)
    fi

    # Get touch device idle time by checking last event time
    # Find touch input devices (typically event0 or event1 for touchscreens)
    for input_device in /dev/input/event*; do
        if [ -r "$input_device" ]; then
            # Get last access time of the device file in seconds since epoch
            local last_access=$(stat -c %X "$input_device" 2>/dev/null || stat -f %a "$input_device" 2>/dev/null || echo 0)
            local current_time=$(date +%s)
            local device_idle_sec=$((current_time - last_access))
            local device_idle_ms=$((device_idle_sec * 1000))

            # Use the minimum idle time from all devices
            if [ "$device_idle_ms" -lt "$touch_idle" ]; then
                touch_idle=$device_idle_ms
            fi
        fi
    done

    # Return the minimum idle time (most recent activity)
    if [ "$x_idle" -lt "$touch_idle" ]; then
        echo "$x_idle"
    else
        echo "$touch_idle"
    fi
}

# Function to progressively dim backlight
backlight_dim() {
    if [ "$STATE" != "off" ]; then
        SAVED_BRIGHTNESS=$(get_brightness)
        local current=$SAVED_BRIGHTNESS
        local step=$(( (current - MIN_BRIGHTNESS) / DIM_STEPS ))

        # Ensure step is at least 1 to avoid infinite loop
        if [ "$step" -lt 1 ]; then
            step=1
        fi

        echo "$(date): Progressively dimming backlight from $current to $MIN_BRIGHTNESS..."

        # Block touch input to prevent ghost touches during wake-up
        block_touch_input

        while [ "$current" -gt "$MIN_BRIGHTNESS" ]; do
            current=$((current - step))
            if [ "$current" -lt "$MIN_BRIGHTNESS" ]; then
                current=$MIN_BRIGHTNESS
            fi
            set_brightness "$current"
            sleep "$DIM_STEP_DELAY"
        done

        STATE="off"
        echo "$(date): Backlight dimmed to $MIN_BRIGHTNESS (was $SAVED_BRIGHTNESS)"
    fi
}

# Function to progressively restore backlight
backlight_on() {
    if [ "$STATE" != "on" ]; then
        local target_brightness
        if [ -n "$SAVED_BRIGHTNESS" ] && [ "$SAVED_BRIGHTNESS" -gt 0 ]; then
            target_brightness="$SAVED_BRIGHTNESS"
        else
            target_brightness="$MAX_BRIGHTNESS"
        fi

        local current=$(get_brightness)
        local step=$(( (target_brightness - current) / DIM_STEPS ))

        # Ensure step is at least 1
        if [ "$step" -lt 1 ]; then
            step=1
        fi

        echo "$(date): Progressively restoring backlight from $current to $target_brightness..."

        while [ "$current" -lt "$target_brightness" ]; do
            current=$((current + step))
            if [ "$current" -gt "$target_brightness" ]; then
                current=$target_brightness
            fi
            set_brightness "$current"
            sleep "$DIM_STEP_DELAY"
        done

        STATE="on"

        # Small delay before unblocking to prevent immediate click-through
        sleep 0.5
        unblock_touch_input

        echo "$(date): Backlight restored to $target_brightness"
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

# Main monitoring loop
echo "Starting backlight dimmer daemon..."
echo "Idle timeout: ${IDLE_TIMEOUT}s"
echo "Check interval: ${CHECK_INTERVAL}s"

while true; do
    # Get idle time in milliseconds
    IDLE_MS=$(get_idle_time)
    IDLE_SECONDS=$((IDLE_MS / 1000))

    if [ "$IDLE_SECONDS" -ge "$IDLE_TIMEOUT" ]; then
        # User has been idle long enough - dim backlight
        backlight_dim
    else
        # User is active - ensure backlight is on
        backlight_on
    fi

    sleep "$CHECK_INTERVAL"
done
