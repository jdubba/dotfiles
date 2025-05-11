#!/bin/bash

## NOTE: Enable execution on installation helper scripts  
chmod +x ./install-scripts/*.sh

./install-scripts/ensure-common-directories.sh

./install-scripts/add-repos.sh

if command -v apt-get >/dev/null 2>&1; then
    sudo apt update
fi

./install-scripts/install-packages.sh
./install-scripts/install-ble.sh.sh
./install-scripts/install-starship.sh
./install-scripts/install-yai.sh
./install-scripts/install-neovim.sh
./install-scripts/install-kitty.sh
./install-scripts/install-webp.sh
./install-scripts/install-xh.sh
./install-scripts/install-fonts.sh

./install-scripts/stow-config.sh
./install-scripts/configure-github.sh
