#!/bin/bash

# Check if -f or --force switch was passed                                                                                                                             
if [[ $1 == "-f" || $1 == "--force" ]]; then                                                                                                                           
    if [ -d "$nvim_dir" ]; then                                                                                                                                            
       sudo rm -rf /opt/nvim
    fi                                                                                                                                                                     
 
    echo "Force flag detected"                                                                                                                                         
fi

# Install the most recent nvim release
if [ -d /opt/nvim ]; then
  echo "Neovim already installed, use -f or --force to force reinstall"
else
  pushd .
  cd ~
  curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
  tar -xzf nvim-linux-x86_64.tar.gz -C /opt --transform='s|^nvim-linux-x86_64|nvim|'
  rm nvim-linux-x86_64.tar.gz

  if [ -f "/usr/bin/nvim" ]; then sudo rm /usr/bin/nvim; fi
  if [ -f "/usr/bin/vim" ]; then sudo rm /usr/bin/vim; fi

  sudo ln -s /opt/nvim/bin/nvim /usr/bin/nvim
  sudo ln -s /opt/nvim/bin/nvim /usr/bin/vim

  popd
fi
