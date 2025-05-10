#!/bin/bash

## NOTE: Enable execution on installation helper scripts  
chmod +x ./install-scripts/*.sh

./install-scripts/ensure-common-directories.sh

./install-scripts/add-repos.sh
sudo apt update

./install-scripts/install-packages.sh
./install-scripts/install-ble.sh.sh
./install-scripts/install-starship.sh
./install-scripts/install-yai.sh

./install-scripts/stow-config.sh
./install-scripts/configure-github.sh
