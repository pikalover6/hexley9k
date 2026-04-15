#!/bin/bash
set -e

INT_VERBOSE=1
IMG=/tmp/hfs_full_test.img

echo "=== Creating APM disk image ==="
dd if=/dev/zero of="$IMG" bs=1M count=200 2>/dev/null

# Create El Torito ISO (like the real assembly does)
mkdir -p /tmp/eltoriso_work
cp /repo/setup/pd_setup_files/boot/i386/* /tmp/eltoriso_work/ 2>/dev/null
ELTORITOISO=/tmp/puredarwin_eltorito_test.iso
genisoimage -quiet -V "PureDarwin" -no-emul-boot -boot-load-size 4 \
    -c boot.cat -b cdboot -o "$ELTORITOISO" /tmp/eltoriso_work 2>&1
rm -rf /tmp/eltoriso_work

ISO_BYTES=$(stat -c %s "$ELTORITOISO")
SECTORS=$(( (ISO_BYTES + 511) / 512 ))
echo "El Torito ISO: $SECTORS sectors"

HFS_START=$SECTORS
[ $HFS_START -lt 64 ] && HFS_START=64

# Partition with APM
parted -s "$IMG" mklabel mac 2>/dev/null
parted -s "$IMG" mkpart PureDarwin hfs+ "${HFS_START}s" 100% 2>/dev/null
LOOP=$(losetup -f --show "$IMG")
LOOP_NAME=$(basename "$LOOP")
kpartx -av "$LOOP" >/dev/null
sleep 0.5
HFS_PART="/dev/mapper/${LOOP_NAME}p2"

echo ""
echo "=== Writing boot0 and El Torito ISO ==="
dd if=/repo/setup/pd_setup_files/boot/i386/boot0 of="$LOOP" bs=512 count=1 conv=notrunc 2>/dev/null
dd if="$ELTORITOISO" of="$LOOP" seek=64 bs=512 conv=notrunc 2>/dev/null
rm -f "$ELTORITOISO"

echo ""
echo "=== Checking HFS+ partition bytes before mkfs (should be El Torito data) ==="
echo "First sector of HFS_PART (should be El Torito data):"
dd if="$HFS_PART" bs=512 count=1 2>/dev/null | hexdump -C | head -4
echo "Byte 1024 of HFS_PART (will be volume header after mkfs):"
dd if="$HFS_PART" bs=1 skip=1024 count=4 2>/dev/null | xxd

echo ""
echo "=== Formatting HFS+ ==="
mkfs.hfsplus -J -v PureDarwin "$HFS_PART"

echo ""
echo "=== Checking HFS+ volume header AFTER mkfs ==="
echo "Byte 1024 of HFS_PART (should be H+ magic bytes):"
dd if="$HFS_PART" bs=1 skip=1024 count=4 2>/dev/null | xxd

# Sync
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

echo ""
echo "=== Checking HFS+ volume header AFTER sync+drop_caches ==="
dd if="$HFS_PART" bs=1 skip=1024 count=4 2>/dev/null | xxd

echo ""
echo "=== Writing boot1h ==="
dd if=/repo/setup/pd_setup_files/boot/i386/boot1h of="$HFS_PART" bs=512 count=1 conv=notrunc 2>/dev/null

sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

echo ""
echo "=== Checking HFS+ volume header AFTER boot1h + sync+drop ==="
dd if="$HFS_PART" bs=1 skip=1024 count=4 2>/dev/null | xxd

echo ""
echo "=== Testing guestmount ==="
KVER=$(ls /lib/modules | grep 5.15.0 | head -1)
MNTPT=/tmp/hfs_full_test_mnt
mkdir -p "$MNTPT"
LIBGUESTFS_KERNEL="/boot/vmlinuz-$KVER" LIBGUESTFS_BACKEND=direct \
    guestmount --rw -a "$HFS_PART" -m "/dev/sda:/:rw,force" "$MNTPT" 2>&1 && \
    (echo "guestmount OK" && guestunmount "$MNTPT") || \
    echo "guestmount FAILED"

kpartx -d "$LOOP" 2>/dev/null || true
losetup -d "$LOOP" 2>/dev/null || true
rm -f "$IMG"
