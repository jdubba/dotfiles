#!/bin/bash

#NOTE:  Package updates for Debian/Ubuntu families

if command -v apt-get >/dev/null 2>&1; then
    # NOTE:  Add the Github.com package source
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
            && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \

    # NOTE:  Add the repo for fastfetch
    sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch

    # NOTE: Add the repo for brave browser
    sudo apt install curl
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg


    # NOTE: Add repo for xh, bat, ripgrep and others
    curl -fsSL https://apt.cli.rs/pubkey.asc | sudo tee -a /usr/share/keyrings/rust-tools.asc
    curl -fsSL https://apt.cli.rs/rust-tools.list | sudo tee /etc/apt/sources.list.d/rust-tools.list
fi


#NOTE:  Package for Fedora/DNF version 5
if command -v dnf >/dev/null 2&1; then 
    if dnf --version | grep -q 'dnf5 version 5\.'; then
        # NOTE: Github CLI
        sudo dnf install dnf5-plugins
        sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo

        # NOTE: Brave browser
        sudo dnf install dnf-plugins-core
        sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    fi
fi
