#!/bin/bash

# TODO:  Rewrite and test, include dnf4 vs dnf5
InstallPackages() {

  if command -v apt-get >/dev/null 2>&1; then
      apt_packages = "$* build-essential"
      sudo apt-get install -y $apt_packages

  elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y $*
      sudo dnf groupinstall "Development Tools" "Development Libraries"
  
  elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y $*
  
  elif command -v zypper >/dev/null 2>&1; then
      sudo zypper -y install $*
  
  elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy $*
  
  else
    printf "Could not determine package manager."
    return 1
 
  fi
}

# Software Installs
common_packages ="git gawk make curl stow fzf bat bash-completion kitty brave-browser gh fastfetch npm ripgrep"
InstallPackages $core_packages
