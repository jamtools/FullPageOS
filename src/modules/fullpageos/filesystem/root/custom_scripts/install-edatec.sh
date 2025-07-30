#!/bin/bash
set -euxo pipefail

# Optional: only run once
MARKER="$HOME/.edatec_installed"
if [ -f "$MARKER" ]; then
  echo "Already installed"
  exit 0
fi

# Run the installer
curl -fsSL https://apt.edatec.cn/bsp/ed-install.sh | sudo bash -s hmi3010_101c

# Mark done
touch "$MARKER"
