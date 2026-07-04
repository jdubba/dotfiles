#!/usr/bin/env bash
# Moves workspaces to a target monitor via hyprctl --batch
# Usage: move-workspaces.sh <monitor> <workspace...>
target="$1"
shift
cmds=""
for ws in "$@"; do
  cmds="${cmds}dispatch moveworkspacetomonitor $ws $target;"
done
hyprctl --batch "$cmds"
