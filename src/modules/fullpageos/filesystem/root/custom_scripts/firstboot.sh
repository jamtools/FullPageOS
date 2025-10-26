#!/bin/bash

set -eux

runuser -l pi -c 'systemctl --user enable install-edatec.service'
runuser -l pi -c 'systemctl --user start install-edatec.service'

runuser -l pi -c 'systemctl --user enable ip-configurator.service'
runuser -l pi -c 'systemctl --user start ip-configurator.service'

runuser -l pi -c 'systemctl --user enable backlight-dimmer.service'
runuser -l pi -c 'systemctl --user start backlight-dimmer.service'

MARKER="$HOME/.edatec_installed"
NETWORK_MARKER="$HOME/.network_configured"
if [ -f "$MARKER" ]; then
  if [ ! -f "$NETWORK_MARKER" ]; then
    # Disable WiFi using rfkill (persistent across reboots via systemd-rfkill)
    sudo rfkill block wifi

    # Set DNS configuration (NetworkManager compatible)
    echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf

    # NetworkManager is already enabled by default in Raspberry Pi OS Bookworm
    # WiFi is disabled via /etc/NetworkManager/conf.d/99-kiosk.conf (unmanaged-devices)

    touch "$NETWORK_MARKER"
  fi
fi
