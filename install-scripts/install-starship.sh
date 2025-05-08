#!/bin/bash

# Install starship
if ! which starship >/dev/null 2>&1; then
   curl -sS https://starship.rs/install.sh | sh
fi
