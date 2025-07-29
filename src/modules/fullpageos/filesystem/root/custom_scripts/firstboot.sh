#!/bin/bash

set -eux

# curl -s https://apt.edatec.cn/bsp/ed-install.sh | sudo bash -s hmi3010_101c

runuser -l pi -c 'systemctl --user enable display-rotate.service'
runuser -l pi -c 'systemctl --user start display-rotate.service'
