#!/bin/bash
set -e
DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl p7zip-full qemu-utils libguestfs-tools 2>/dev/null

echo '=== Downloading NBE ==='
curl -fsSL -o /tmp/nbe.7z 'https://github.com/PureDarwin/LegacyDownloads/releases/download/PDXMASNBE01/NewBootEnvironment-XMas-1.7z'
echo 'Done'
7z e /tmp/nbe.7z -o/tmp/nbe/ -y 2>/dev/null
qemu-img convert -O raw /tmp/nbe/puredarwinxmas.vmdk /tmp/nbe.raw

echo '=== NBE Boot.plist ==='
LIBGUESTFS_BACKEND=direct guestfish --ro -a /tmp/nbe.raw << 'GEOF'
run
list-filesystems
mount /dev/sda1 /
cat /Library/Preferences/SystemConfiguration/com.apple.Boot.plist
GEOF

echo '=== NBE /Extra contents ==='
LIBGUESTFS_BACKEND=direct guestfish --ro -a /tmp/nbe.raw << 'GEOF'
run
mount /dev/sda1 /
-ls /Extra
GEOF

echo '=== NBE /boot size ==='
LIBGUESTFS_BACKEND=direct guestfish --ro -a /tmp/nbe.raw << 'GEOF'
run
mount /dev/sda1 /
stat /boot
GEOF

echo '=== NBE System/Library/Extensions kext list (VMware) ==='
LIBGUESTFS_BACKEND=direct guestfish --ro -a /tmp/nbe.raw << 'GEOF'
run
mount /dev/sda1 /
ls /System/Library/Extensions
GEOF
