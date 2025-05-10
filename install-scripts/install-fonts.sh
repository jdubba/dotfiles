#!/bin/bash

mkdir -p ~/.fonts

pushd .
cd ~/scratch

# NOTE:  Monoid Nerd Font
if [[ -d ~/.fonts/Monoid ]]; then rm -rf ~/.fonts/Monoid; fi
mkdir ~/.fonts/Monoid

xh --download https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Monoid.tar.xz

tar -C ~/.fonts -xJvf Monoid.tar.xz

rm Monoid.tar.xz

# NOTE:  Refresh font cache
fc-cache -f ~/.fonts

popd
