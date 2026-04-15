#!/bin/bash
set -e

echo "=== Test 1: raw HFS+ file image ==="
dd if=/dev/zero of=/tmp/hfs-test.img bs=1M count=50 2>/dev/null
mkfs.hfsplus -v TestVol /tmp/hfs-test.img
LIBGUESTFS_KERNEL="/boot/vmlinuz-$(ls /lib/modules | grep 5.15.0 | head -1)" \
LIBGUESTFS_BACKEND=direct \
guestfish --rw -a /tmp/hfs-test.img \
    run : mount /dev/sda / : write /test-hfs.txt 'FILE OK' : cat /test-hfs.txt
echo ""

echo "=== Test 2: HFS+ via loop+kpartx block device ==="
dd if=/dev/zero of=/tmp/hfs-disk.img bs=1M count=200 2>/dev/null
# Partition with APM
parted -s /tmp/hfs-disk.img mklabel mac
parted -s /tmp/hfs-disk.img mkpart TestVol hfs+ 2076s 100%
LOOP=$(losetup -f --show /tmp/hfs-disk.img)
kpartx -av "$LOOP" >/dev/null
LOOP_NAME=$(basename "$LOOP")
HFS_PART="/dev/mapper/${LOOP_NAME}p2"
sleep 1
echo "HFS_PART: $HFS_PART"
ls -la "$HFS_PART"
mkfs.hfsplus -v TestVol "$HFS_PART"
echo "Attempting guestmount on block device..."
KVER=$(ls /lib/modules | grep 5.15.0 | head -1)
LIBGUESTFS_KERNEL="/boot/vmlinuz-$KVER" \
LIBGUESTFS_BACKEND=direct \
guestfish --rw -a "$HFS_PART" \
    run : mount /dev/sda / : write /test-hfs.txt 'BLOCK OK' : cat /test-hfs.txt
kpartx -d "$LOOP" 2>/dev/null || true
losetup -d "$LOOP" 2>/dev/null || true
