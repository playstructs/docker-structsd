#!/usr/bin/env bash

# Install Go

echo "Installing go"
system_version=$(uname -a)
#echo system_version

if [[ "system_version" =~ "aarch64" ]]; then
  echo "System is arch64"
   wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz -P ~/
   rm -rf /usr/local/go
   tar -C /usr/local -xzf ~/go1.21.0.linux-amd64.tar.gz
elif [[ "system_version" =~ "arm64" ]]; then
  echo "moo"
else
  echo "Filename does not have a .txt extension"
fi