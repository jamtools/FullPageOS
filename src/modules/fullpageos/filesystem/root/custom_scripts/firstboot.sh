#!/bin/bash

set -eux

# Check if firstboot has already run
FIRSTBOOT_MARKER="/var/lib/firstboot_completed"
if [ -f "$FIRSTBOOT_MARKER" ]; then
    echo "First boot setup already completed, exiting..."
    exit 0
fi

runuser -l pi -c 'systemctl --user enable display-rotate.service'
runuser -l pi -c 'systemctl --user start display-rotate.service'

# Mark firstboot as completed before potentially rebooting
touch "$FIRSTBOOT_MARKER"

curl -s https://apt.edatec.cn/bsp/ed-install.sh | sudo bash -s hmi3010_101c
