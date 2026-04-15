#!/bin/bash
set -e
_kv=$(ls /lib/modules/ | grep -E '^5\.15\.0-.*-generic$' | sort -V | tail -1)
echo "Kernel version: $_kv"

# Inject hfsplus into supermin hostfiles
echo "/lib/modules/$_kv/kernel/fs/hfsplus/hfsplus.ko" >> /usr/lib/x86_64-linux-gnu/guestfs/supermin.d/hostfiles
echo "Injected hfsplus into supermin hostfiles"

# Rebuild appliance cache
rm -rf /var/tmp/.guestfs-0/
LIBGUESTFS_KERNEL="/boot/vmlinuz-$_kv" LIBGUESTFS_BACKEND=direct guestfish -a /dev/null run : shutdown 2>&1 | tail -3
echo "Appliance rebuilt"

# Test: create HFS+ image and mount it
dd if=/dev/zero of=/tmp/hfs-test.img bs=1M count=50 2>/dev/null
mkfs.hfsplus -v TestVol /tmp/hfs-test.img

LIBGUESTFS_KERNEL="/boot/vmlinuz-$_kv" LIBGUESTFS_BACKEND=direct \
guestfish --rw -a /tmp/hfs-test.img \
    run : mount /dev/sda / : write /test-hfs.txt 'IT WORKS' : cat /test-hfs.txt
