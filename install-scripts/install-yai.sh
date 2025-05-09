#!/bin/bash

#TODO: Replace with better install method
pushd .
cd ~/scratch

curl -sS https://raw.githubusercontent.com/ekkinox/yai/main/install.sh | bash

# NOTE: Installer leaves this file sitting around
rm CHANGELOG.md

popd
