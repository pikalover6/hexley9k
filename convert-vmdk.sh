#!/bin/bash
set -e

ISO_SRC="/repo/puredarwin.vmwarevm/puredarwin.iso"
ISO_TMP="/tmp/puredarwin.iso"
VMDK_TMP="/tmp/puredarwin.vmdk"
VMDK_DST="/repo/puredarwin.vmwarevm/puredarwin.vmdk"

echo "File size check:"
ls -la "$ISO_SRC"

echo ""
echo "Checking first 512 bytes (boot record)..."
dd if="$ISO_SRC" bs=512 count=1 2>/dev/null | xxd | head -4

echo ""
echo "Copying to Linux tmp (bypassing Windows I/O)..."
dd if="$ISO_SRC" of="$ISO_TMP" bs=4M status=progress 2>&1

echo "Copied. Size:"
ls -la "$ISO_TMP"

echo ""
echo "Converting to VMDK with system qemu-img..."
which qemu-img
qemu-img convert -O vmdk -p "$ISO_TMP" "$VMDK_TMP"

echo "Converting complete."
ls -la "$VMDK_TMP"

echo "Copying VMDK back to volume mount..."
dd if="$VMDK_TMP" of="$VMDK_DST" bs=4M status=progress 2>&1

echo "Done. VMDK created at: $VMDK_DST"
ls -la "$VMDK_DST"
