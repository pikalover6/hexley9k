#!/bin/bash
set -e

# Create similar setup to actual assembly
IMG=/tmp/hfs_assembly_test.img
dd if=/dev/zero of="$IMG" bs=1M count=200 2>/dev/null
parted -s "$IMG" mklabel mac 2>/dev/null
parted -s "$IMG" mkpart PureDarwin hfs+ 2076s 100% 2>/dev/null
LOOP=$(losetup -f --show "$IMG")
kpartx -av "$LOOP" >/dev/null
sleep 0.5
LOOP_NAME=$(basename "$LOOP")
HFS_PART="/dev/mapper/${LOOP_NAME}p2"
mkfs.hfsplus -J -v PureDarwin "$HFS_PART"

BOOT1H=/repo/setup/pd_setup_files/boot/i386/boot1h
dd if="$BOOT1H" of="$HFS_PART" bs=512 count=1 conv=notrunc 2>/dev/null

KVER=$(ls /lib/modules | grep 5.15.0 | head -1)
MNTPT=/tmp/hfs_test_mnt
mkdir -p "$MNTPT"

echo "=== Test 1: guestmount with rw,force ==="
LIBGUESTFS_KERNEL="/boot/vmlinuz-$KVER" \
LIBGUESTFS_BACKEND=direct \
guestmount --rw -a "$HFS_PART" -m "/dev/sda:/:rw,force" "$MNTPT" 2>&1 && \
    (echo test > "$MNTPT/test.txt" && echo "MOUNT+WRITE OK" && guestunmount "$MNTPT") || \
    echo "FAILED with rw,force"

echo ""
echo "=== Test 2: guestmount with just rw (no force) ==="
LIBGUESTFS_KERNEL="/boot/vmlinuz-$KVER" \
LIBGUESTFS_BACKEND=direct \
guestmount --rw -a "$HFS_PART" -m "/dev/sda:/:rw" "$MNTPT" 2>&1 && \
    (echo test > "$MNTPT/test.txt" && echo "MOUNT+WRITE OK" && guestunmount "$MNTPT") || \
    echo "FAILED with rw"

echo ""
echo "=== Test 3: guestmount with rw,force and explicit hfsplus ==="
LIBGUESTFS_KERNEL="/boot/vmlinuz-$KVER" \
LIBGUESTFS_BACKEND=direct \
guestmount --rw -a "$HFS_PART" -m "/dev/sda:/:rw,force:hfsplus" "$MNTPT" 2>&1 && \
    (echo test > "$MNTPT/test.txt" && echo "MOUNT+WRITE OK" && guestunmount "$MNTPT") || \
    echo "FAILED with rw,force:hfsplus"

kpartx -d "$LOOP" 2>/dev/null || true
losetup -d "$LOOP" 2>/dev/null || true
rm -f "$IMG"
