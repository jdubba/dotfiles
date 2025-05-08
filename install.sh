#!/bin/bash

## NOTE: Enable execution on installation helper scripts  
chmod +x ./install-scripts/*.sh

./install-scripts/ensure-common-directories.sh
./install-scripts/stow-config.sh
./install-scripts/install-packages.sh
