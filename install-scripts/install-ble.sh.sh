#!/bin/bash

if ! [ -d ~/source/ble.sh ]; then
  echo "Installing ble.sh"
  pushd .

  if [ -d ~/.local/share/blesh ]; then
    echo "Local install found, removing"
    rm -rf ~/.local/share/blesh
  fi

  cd ~/source
  git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh.git
  make -C ble.sh install PREFIX=~/.local

  popd
else
  echo "ble.sh already present"
fi
