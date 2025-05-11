#!/bin/bash

# NOTE:  Symlink all items in ./scripts to ~/.local/bin

for file in ./scripts; do                                                                                                                                 
    ln -s "$file" ~/.local/bin/$(basename "$file")                                                                                                                    
done
