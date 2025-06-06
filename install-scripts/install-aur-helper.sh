#!/bin/bash

# Function to detect Arch Linux or Arch-based distributions
IsArchBased() {
  if [ -f /etc/arch-release ]; then
    return 0
  elif [ -f /etc/os-release ]; then
    if grep -q "ID_LIKE.*arch" /etc/os-release || grep -q "ID=arch" /etc/os-release; then
      return 0
    fi
  fi
  return 1
}

# Function to install AUR helper on Arch Linux
InstallAURHelper() {
  # Only proceed if we're on Arch or Arch-based system
  if ! IsArchBased; then
    echo "Not an Arch-based system, skipping AUR helper installation"
    return 0
  fi

  # Check if pacman is available
  if ! command -v pacman >/dev/null 2>&1; then
    echo "pacman not found, cannot install AUR helper"
    return 1
  fi

  if command -v yay >/dev/null 2>&1; then
    echo "yay already installed"
    return 0
  elif command -v paru >/dev/null 2>&1; then
    echo "paru already installed"
    return 0
  else
    echo "Installing yay AUR helper..."
    
    # Install prerequisites
    sudo pacman -S --needed --noconfirm base-devel git
    
    # Clone and build yay
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    
    # Cleanup
    cd ~
    rm -rf /tmp/yay
    
    echo "yay AUR helper installed successfully"
  fi
}

# Run the installation if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  InstallAURHelper
fi