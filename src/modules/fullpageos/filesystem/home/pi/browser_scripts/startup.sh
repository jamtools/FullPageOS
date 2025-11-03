#!/bin/bash
[ -z "$DISPLAY" ] && DISPLAY=:0
export DISPLAY

# Get our location
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Clear Chromium cache and problematic state files that tend to corrupt
# This preserves:
# - User-trusted certificates (stored in ~/.pki/nssdb, separate from chromium config)
# - Extension state (chromium-keyboard)
# - Some preferences that don't cause corruption
# if [ -z "$RUNNING_IN_DOCKER" ]; then

# Clear main cache directory
rm -rf "$HOME/.cache/chromium"

# Clear specific problematic directories within config
rm -rf "$HOME/.config/chromium/Default/Cache"
rm -rf "$HOME/.config/chromium/Default/Code Cache"
rm -rf "$HOME/.config/chromium/Default/GPUCache"
rm -rf "$HOME/.config/chromium/ShaderCache"
rm -rf "$HOME/.config/chromium/Default/Service Worker"

# Clear crash reports and session data that can cause startup issues
rm -rf "$HOME/.config/chromium/Crash Reports"
rm -f "$HOME/.config/chromium/SingletonLock"
rm -f "$HOME/.config/chromium/Default/Cookies"
rm -f "$HOME/.config/chromium/Default/Cookies-journal"

# Clear session storage and local storage if they exist
rm -rf "$HOME/.config/chromium/Default/Session Storage"
rm -rf "$HOME/.config/chromium/Default/Local Storage"

# fi

# Autohide mouse when inactive
unclutter &

# Disable DPMS and screen blanking - we handle backlight control manually via backlight-dimmer.sh
# This prevents conflicts between X11 power management and our custom backlight control
xset s off              # Disable screen saver
xset s noblank          # Don't blank the screen
xset -dpms              # Disable DPMS (Display Power Management Signaling)

# # Give pi account a complex random password
# if [ -z "$RUNNING_IN_DOCKER" ] && [ -e "/boot/autosecure" ]
# then
#     NEWPW="hardcode"
#     # NEWPW="$(openssl rand -base64 32 | tr -d 'EOF')"
#     passwd <<EOF
#     raspberry
#     $NEWPW
#     $NEWPW
# EOF
# fi

# Start Python-based controller to ensure reloads on load failures
# if [ -n "$RUNNING_IN_DOCKER" ]; then
#     python3 "$DIR/chromium_controller.py" "$(head -n 1 /config/mutesound.txt)" &
# else
python3 "$DIR/chromium_controller.py" "$(head -n 1 /boot/mutesound.txt)" 2>&1 | tee /home/pi/controller-debug.log &
# fi

BROWSER="$(command -v chromium-browser)"
[ -z "$BROWSER" ] && BROWSER="$(command -v chromium)"


# Start Chromium
# if [ -n "$RUNNING_IN_DOCKER" ]; then
#     $BROWSER --kiosk --touch-events=enabled --disable-pinch --noerrdialogs --disable-session-crashed-bubble --start-fullscreen --remote-debugging-port=9222 --app="file:///config/placeholder.html" --force-renderer-accessibility
# else
while true; do
    $BROWSER --kiosk --touch-events=enabled --disable-pinch --noerrdialogs --disable-session-crashed-bubble --start-fullscreen --remote-debugging-port=9222 --app="file:///boot/placeholder.html" --force-renderer-accessibility --load-extension=/home/pi/chromium-keyboard --enable-logging=stderr --force-device-scale-factor=0.9 2>&1 | tee /home/pi/chromium-debug.log
done
# fi
