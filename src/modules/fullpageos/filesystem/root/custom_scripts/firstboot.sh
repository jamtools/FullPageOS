#!/bin/bash

set -eux

runuser -l pi -c 'systemctl --user enable install-edatec.service'
runuser -l pi -c 'systemctl --user start install-edatec.service'

runuser -l pi -c 'systemctl --user enable ip-configurator.service'
runuser -l pi -c 'systemctl --user start ip-configurator.service'
