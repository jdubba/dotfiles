#!/bin/bash

stow_directory=$(pwd)
stow_target_directory=$HOME

## NOTE:  Establish config symlinks, using --adopt followed by git restore to ensure links for any files that already exist
stow -v --adopt -d $stow_directory -t $stow_target_directory config
git restore .
