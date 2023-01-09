#/bin/bash

# Downloads and builds Papyrus, with some local modifications.

set -e

apt-get update

apt-get install -y libgdiplus libc6-dev git curl

# Downgrade to libgdiplus 4.2-2 (which is significantly faster than later
# versions for this app's purpose)
curl -O http://launchpadlibrarian.net/306727216/libgdiplus_4.2-2_amd64.deb
dpkg -i libgdiplus_4.2-2_amd64.deb
rm libgdiplus_4.2-2_amd64.deb

# Install, patch and build Papyrus
git clone https://github.com/papyrus-mc/papyruscs
cd papyruscs
git apply ../papyruscs.patch
git remote add chrisl8 https://github.com/chrisl8/papyruscs
git pull chrisl8 master
dotnet publish PapyrusCs -c Debug --self-contained --runtime linux-x64 -o ../papyrus-out
cd ..
