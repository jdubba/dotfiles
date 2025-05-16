#!/bin/bash

# Install starship
if ! which starship >/dev/null 2>&1; then
    pushd .
    cd ~/scratch
    curl -LO https://starship.rs/install.sh
    chmod +x install.sh
    ./install.sh -y
    rm install.sh
    popd
fi
