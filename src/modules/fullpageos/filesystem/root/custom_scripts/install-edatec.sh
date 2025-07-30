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


sudo update-ca-certificates --fresh

for i in {1..5}; do
  if curl -fsSL https://apt.edatec.cn/bsp/ed-install.sh -o /tmp/ed-install.sh; then
    break
  fi
  echo "curl failed, retrying in 5 seconds..."
  sleep 5
done

if [ ! -f /tmp/ed-install.sh ]; then
  echo "Failed to download ed-install.sh"
  exit 1
fi

touch "$MARKER"

sudo bash /tmp/ed-install.sh hmi3010_101c
