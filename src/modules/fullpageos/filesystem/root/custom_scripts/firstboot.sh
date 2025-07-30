#!/bin/bash

set -eux

runuser -l pi -c 'systemctl --user enable display-rotate.service'
runuser -l pi -c 'systemctl --user start display-rotate.service'

runuser -l pi -c 'systemctl --user enable install-edatec.service'
runuser -l pi -c 'systemctl --user start install-edatec.service'
