#!/bin/bash

pushd .

cd ~/scratch

curl -LO https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.5.0-rc1-linux-x86-64.tar.gz

tar -C /opt -xzvf libwebp-1.5.0-rc1-linux-x86-64.tar.gz --transform='s|^libwebp-1.5.0-rc1-linux-x86-64|libwebp|'

for file in /opt/libwebp/bin/*; do                                                                                                                                 
    sudo ln -s "$file" /usr/bin/$(basename "$file")                                                                                                                    
done

rm libwebp-1.5.0-rc1-linux-x86-64.tar.gz

popd
