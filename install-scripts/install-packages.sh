#!/bin/bash

# TODO:  Rewrite and test, include dnf4 vs dnf5
InstallPackages() {
  printf "Ensuring package installation for $*\n"

  printf "Installing $*\n"

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y $*
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y $*
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
core_packages="git gawk make curl stow fzf bat bash-completion webp kitty brave-browser gh fastfetch build-essential npm xh ripgrep"
InstallPackages $core_packages
