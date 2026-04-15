#!/bin/bash
set -e

echo "=== Test: HFS+ via block device WITH boot1h written first ==="
dd if=/dev/zero of=/tmp/hfs-disk.img bs=1M count=200 2>/dev/null
parted -s /tmp/hfs-disk.img mklabel mac 2>/dev/null
parted -s /tmp/hfs-disk.img mkpart TestVol hfs+ 2076s 100% 2>/dev/null
LOOP=$(losetup -f --show /tmp/hfs-disk.img)
kpartx -av "$LOOP" >/dev/null
LOOP_NAME=$(basename "$LOOP")
HFS_PART="/dev/mapper/${LOOP_NAME}p2"
sleep 1
mkfs.hfsplus -J -v PureDarwin "$HFS_PART"

# Write boot1h to sector 0 of the HFS+ partition
BOOT1H=/repo/setup/pd_setup_files/boot/i386/boot1h
echo "Writing boot1h to sector 0 of HFS+ partition..."
dd if="$BOOT1H" of="$HFS_PART" bs=512 count=1 conv=notrunc 2>&1

echo "Checking HFS+ signature after boot1h write..."
hexdump -C "$HFS_PART" 2>/dev/null | head -5
echo "Byte 1024 (HFS+ volume header magic):"
dd if="$HFS_PART" bs=1 skip=1024 count=2 2>/dev/null | xxd

echo ""
echo "Attempting guestmount on block device with boot1h..."
KVER=$(ls /lib/modules | grep 5.15.0 | head -1)
LIBGUESTFS_KERNEL="/boot/vmlinuz-$KVER" \
LIBGUESTFS_BACKEND=direct \
guestfish --rw -a "$HFS_PART" \
    run : mount-options "rw,force" /dev/sda / : write /test-hfs.txt 'BOOT1H OK' : cat /test-hfs.txt
kpartx -d "$LOOP" 2>/dev/null || true
losetup -d "$LOOP" 2>/dev/null || true
