#!/bin/bash
# Clean up leaked loop devices for puredarwin.vmwarevm
for d in 2 3 4 5 6 7 8 9 10; do
  if losetup /dev/loop$d 2>/dev/null | grep -q vmwarevm; then
    kpartx -d /dev/loop$d 2>/dev/null || true
    losetup -d /dev/loop$d 2>/dev/null || true
    echo "Cleaned loop$d"
  fi
done

# Test absolute path losetup
_abs=$(cd /repo && pwd)/puredarwin.vmwarevm
echo "Absolute path: $_abs"
ls -la "$_abs"
LOOP=$(losetup -f --show "$_abs")
echo "Loop device: $LOOP"
losetup -d "$LOOP"
echo "OK: absolute path losetup works"
