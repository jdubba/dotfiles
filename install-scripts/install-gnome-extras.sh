#!/bin/bash

if [[ $XDG_CURRENT_DESKTOP == *"GNOME"* ]]; then
    # NOTE:  Should work for dnf4 and dnf5
    if command -v dnf >/dev/null 2>&1; then 
        sudo dnf install pipx gnome-shell-extension-pop-shell
        pipx install gnome-extensions-cli --system-site-packages 

        gext install openbar@neuromorph
        gext install space-bar@luchrioh
        gext install extension-list@tu.berry
        gext install rounded-window-corners@fxgn
        gext install tophat@fflewddur.github.io
        gext install top-bar-organizer@julian.gse.jsts.xyz
    fi

    dconf load ./res/media-keybindings
    dconf load ./res/wm-keybindings
fi
