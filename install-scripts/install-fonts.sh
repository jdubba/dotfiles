#!/bin/bash

InstallNerdFonts() {
    for item in "$@"; do                                                                                                                                                                                                                                                                                                                       
        if [[ ! -d "$HOME/.fonts/$item" ]]; then 
            mkdir -p "$HOME/.fonts/$item"
            xh --download "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$item.tar.xz"
            
            tar -C "$HOME/.fonts/$item" -xJvf "$item.tar.xz"

            rm "$item.tar.xz"
        else
            echo "$item already installed.  Skipping installation."
        fi
    done
}

InstallGoogleFont() {
    if [[ ! -d "$HOME/.fonts/$1" ]]; then
        mkdir -p "$HOME/.fonts/$1"

        pushd .
        cd "$HOME/.fonts/$1"
        
        xh --download -o font-def.css -v "$2" 

        curl --remote-name-all $(cat font-def.css | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*")

        rm font-def.css

        popd
    else
        echo "$1 already installed. Skipping installation."
    fi
}

mkdir -p ~/.fonts

pushd .
cd ~/scratch

nerd_fonts="3270 OpenDyslexic Monoid Iosevka IosevkaTerm IosevkaTermSlab Meslo DaddyTimeMono FiraCode FiraMono ProFont Terminus ZedMono ShareTechMono"
InstallNerdFonts $nerd_fonts

InstallGoogleFont Orbitron "https://fonts.googleapis.com/css2?family=Orbitron:wght@400..900&display=swap"
InstallGoogleFont Audiowide "https://fonts.googleapis.com/css2?family=Audiowide&display=swap"
InstallGoogleFont Geo "https://fonts.googleapis.com/css2?family=Geo:ital@0;1&display=swap"
#InstallGoogleFont ShareTechMono "https://fonts.googleapis.com/css2?family=Share+Tech+Mono&display=swap"

# NOTE:  Refresh font cache
fc-cache -f ~/.fonts

popd
