#!/bin/bash
set -e
DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl p7zip-full qemu-utils fdisk xxd libguestfs-tools 2>/dev/null

echo '=== Downloading NBE ==='
curl -fsSL -o /tmp/nbe.7z 'https://github.com/PureDarwin/LegacyDownloads/releases/download/PDXMASNBE01/NewBootEnvironment-XMas-1.7z'
echo 'Download complete'
mkdir -p /tmp/nbe
7z e /tmp/nbe.7z -o/tmp/nbe/ -y 2>/dev/null
ls -lh /tmp/nbe/

echo '=== Converting VMDK to raw ==='
qemu-img convert -O raw /tmp/nbe/puredarwinxmas.vmdk /tmp/nbe.raw

echo '=== MBR first 512 bytes ==='
xxd /tmp/nbe.raw | head -32

echo '=== Partition table (bytes 446-511) ==='
dd if=/tmp/nbe.raw bs=1 skip=446 count=66 2>/dev/null | xxd

echo '=== fdisk -l ==='
fdisk -l /tmp/nbe.raw 2>/dev/null || sfdisk -l /tmp/nbe.raw

echo '=== Sector 1 first 64 bytes (MBR gap: GRUB core or empty?) ==='
dd if=/tmp/nbe.raw bs=512 skip=1 count=1 2>/dev/null | xxd | head -8

START=$(sfdisk -l /tmp/nbe.raw 2>/dev/null | awk '/[0-9]+[[:space:]]+[0-9]+/{print $2; exit}')
echo "=== HFS partition at sector: $START ==="
echo '=== HFS boot sector (boot1h?) ==='
dd if=/tmp/nbe.raw bs=512 skip="$START" count=1 2>/dev/null | xxd | head -16

echo '=== Checking Boot.plist via guestfish ==='
LIBGUESTFS_BACKEND=direct guestfish --ro -a /tmp/nbe.raw << 'GEOF'
run
list-filesystems
mount /dev/sda1 /
ls /
cat /Library/Preferences/SystemConfiguration/com.apple.Boot.plist
GEOF
