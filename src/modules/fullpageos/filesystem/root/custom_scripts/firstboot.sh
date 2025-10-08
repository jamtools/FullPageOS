#!/bin/bash

set -eux

runuser -l pi -c 'systemctl --user enable install-edatec.service'
runuser -l pi -c 'systemctl --user start install-edatec.service'

runuser -l pi -c 'systemctl --user enable ip-configurator.service'
runuser -l pi -c 'systemctl --user start ip-configurator.service'

MARKER="$HOME/.edatec_installed"
NETWORK_MARKER="$HOME/.network_configured"
if [ -f "$MARKER" ]; then
  if [ ! -f "$NETWORK_MARKER" ]; then
#     sudo mkdir -p /etc/NetworkManager/conf.d
#     cat <<'EOF' | sudo tee /etc/NetworkManager/conf.d/unmanaged-eth0.conf >/dev/null
# [keyfile]
# unmanaged-devices=interface-name:eth0
# EOF

    echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf

    sudo systemctl disable --now NetworkManager
    sudo systemctl enable --now systemd-networkd

    touch "$NETWORK_MARKER"
  fi
fi
