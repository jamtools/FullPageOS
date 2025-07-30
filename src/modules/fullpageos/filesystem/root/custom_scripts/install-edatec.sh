#!/bin/bash
set -euxo pipefail

# Optional: only run once
MARKER="$HOME/.edatec_installed"
if [ -f "$MARKER" ]; then
  systemctl --user enable display-rotate.service
  systemctl --user start display-rotate.service

  echo "Already installed"
  exit 0
fi

while [ "$(date +%s)" -lt 1704067200 ]; do
  echo "Waiting for system clock to be synced..."
  echo $(date)
  sleep 2
done

# Mark done
touch "$MARKER"

# Run the installer
curl -fsSL https://apt.edatec.cn/bsp/ed-install.sh | sudo bash -s hmi3010_101c
