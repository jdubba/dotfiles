#!/bin/bash

# NOTE:  Rewrite and test, include dnf4 vs dnf5

# Function to map packages to distribution-specific names
MapPackages() {
  local packages="$*"
  
  if command -v pacman >/dev/null 2>&1; then
    # Map packages for Arch Linux
    packages=$(echo "$packages" | sed 's/brave-browser/brave-bin/g')
    packages=$(echo "$packages" | sed 's/gh/github-cli/g')
  fi
  
  echo "$packages"
}

InstallPackages() {
  local mapped_packages
  mapped_packages=$(MapPackages "$*")

  if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get install -y $mapped_packages build-essential

  elif command -v dnf >/dev/null 2>&1; then
      
    if dnf --version | grep -q 'dnf5 version 5\.'; then
      sudo dnf install -y $mapped_packages
      sudo dnf group install -y c-development development-tools development-libs
    
    elif dnf --version | grep -q '4\.'; then
      sudo dnf install -y $mapped_packages
      sudo dnf groupinstall -y "C Development Tools and Libraries" "Development Tools"
    fi

  elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y $mapped_packages
  
  elif command -v zypper >/dev/null 2>&1; then
      sudo zypper -y install $mapped_packages
  
  elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Syu --noconfirm
      
      # Add base-devel for Arch (equivalent to build-essential)
      local arch_packages="$mapped_packages base-devel"
      
      # Use AUR helper if available, otherwise use pacman
      if command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm $arch_packages
      elif command -v paru >/dev/null 2>&1; then
        paru -S --needed --noconfirm $arch_packages
      else
        sudo pacman -S --needed --noconfirm $arch_packages
      fi
  
  else
    printf "Could not determine package manager."
    return 1
 
  fi
}

# Software Installs
common_packages="git gawk make curl stow fzf bat bash-completion kitty brave-browser gh fastfetch npm ripgrep"
InstallPackages $common_packages
