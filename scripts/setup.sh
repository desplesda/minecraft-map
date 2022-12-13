#!/bin/bash

# Sets up the application's container, ready for use by run.sh

set -e

apt-get update
  
# Install prerequisites
apt-get install -y libgdiplus unzip jq curl libxml2-utils

# Downgrade to libgdiplus 4.2-2 (which is significantly faster than later
# versions for this app's purpose)
curl -O http://launchpadlibrarian.net/306727216/libgdiplus_4.2-2_amd64.deb
dpkg -i libgdiplus_4.2-2_amd64.deb
rm libgdiplus_4.2-2_amd64.deb

# Download and extract azcopy
curl -L https://aka.ms/downloadazcopy-v10-linux -o azcopy.tar.gz
tar zxfv azcopy.tar.gz --strip-components 1 --wildcards --no-anchored "*azcopy"
rm azcopy.tar.gz

# TODO: maybe download the texture pack and set that up?
