#!/bin/bash
echo "=== Current loop devices ==="
losetup -a 2>&1

echo "=== Cleaning up all leaked loop devices ==="
for d in $(losetup -a 2>/dev/null | grep -v 'docker-desktop\|docker-wsl' | awk -F: '{print $1}'); do
    kpartx -d "$d" 2>/dev/null || true
    losetup -d "$d" 2>/dev/null && echo "Cleaned: $d" || true
done

echo "=== After cleanup ==="
losetup -a 2>&1

echo "=== Files in /repo ==="
ls -la /repo/*.img /repo/*.vmwarevm 2>/dev/null || echo "none"

echo "=== Testing fresh file losetup ==="
dd if=/dev/zero of=/repo/losetup_test.img bs=1M count=5 2>/dev/null
ls -la /repo/losetup_test.img
losetup -f --show /repo/losetup_test.img && echo "losetup OK" || echo "losetup FAIL"
LOOP=$(losetup -j /repo/losetup_test.img 2>/dev/null | cut -d: -f1 | head -1)
[ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null || true
rm -f /repo/losetup_test.img
