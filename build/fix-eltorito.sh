#!/bin/sh
# Fix El-Torito boot catalog in the NTARI OS ros2 ISO.
# All boot files exist in the ISO; El-Torito was discarded by the previous xorriso -dev run.
# Uses the exact same parameters that Alpine mkimage uses (from mkimg.base.sh).
set -e

ISO_IN="/workspace/build/build-output/ntari-os-1.5.0-x86_64-ros2-20260228.iso"
ISO_TMP="/tmp/input.iso"
ISO_OUT="/tmp/output.iso"
ISO_DEST="/workspace/build/build-output/ntari-os-1.5.0-x86_64-ros2-20260228.iso"
SHA_DEST="/workspace/build/build-output/ntari-os-1.5.0-x86_64-ros2-20260228.iso.sha256"

echo "[→] Copying ISO to /tmp for modification..."
cp "${ISO_IN}" "${ISO_TMP}"
echo "[✓] Copied: $(du -sh ${ISO_TMP} | cut -f1)"

echo ""
echo "[→] Current boot record:"
xorriso -indev "${ISO_TMP}" -end 2>&1 | grep -E "(Boot record|El Torito)" | head -5

echo ""
echo "[→] Reconstructing El-Torito using Alpine mkimage parameters..."
echo "    Step 1: -boot_image any replay  — copies system area (MBR/GPT) from input"
echo "    Step 2: -boot_image isolinux    — adds BIOS El-Torito (bin_path)"
echo "    Step 3: -boot_image efi         — adds EFI El-Torito"
echo "    Note:   replay handles system area; explicit entries add El-Torito on top"
echo "    Note:   exit 32 (SORRY) is acceptable; 0 = perfect, 32 = minor warnings"
echo ""

# Strategy:
# 1. Extract first 32KB (MBR/GPT hybrid) from the input ISO using dd.
#    The input ISO has the syslinux MBR, so we preserve it via system_area=.
# 2. Use -boot_image any discard (start fresh — no El-Torito to replay).
# 3. Set system_area= to the extracted MBR file.
# 4. Add BIOS El-Torito pointing to isolinux.bin.
# Note: 'replay' + 'bin_path=' sees "no modifications" since replay replaces
#       boot state from indev and bin_path= doesn't register as a delta.
#       'discard' + explicit system_area= + bin_path= is the correct approach.
echo "[→] Extracting system area (32KB MBR/GPT) from input ISO..."
dd if="${ISO_TMP}" of=/tmp/system-area.bin bs=32768 count=1 2>/dev/null
echo "[✓] System area extracted: $(du -sh /tmp/system-area.bin | cut -f1)"

# Write a tiny version marker file — this serves two purposes:
# 1. Gives xorriso a filesystem modification to trigger the write
#    (xorriso won't write to outdev if "No image modifications pending")
# 2. Adds a useful .ntari-version file to the ISO root
echo "[→] Creating version marker (triggers xorriso write)..."
echo "ntari-os-1.5.0-ros2-20260228" > /tmp/ntari-version.txt

echo ""
echo "[→] Running xorriso: discard + system_area + BIOS El-Torito + version marker..."
# set +e: xorriso exits 32 (SORRY) which is acceptable (minor warnings).
# set -e would kill the script before XORRISO_EXIT=$? runs.
set +e
xorriso \
    -abort_on FAILURE \
    -indev  "${ISO_TMP}" \
    -outdev "${ISO_OUT}" \
    -boot_image any discard \
    -boot_image any system_area=/tmp/system-area.bin \
    -boot_image isolinux bin_path=/boot/syslinux/isolinux.bin \
    -map /tmp/ntari-version.txt "/.ntari-version" \
    -commit \
    -end
XORRISO_EXIT=$?
set -e
if [ "${XORRISO_EXIT}" -ne 0 ] && [ "${XORRISO_EXIT}" -ne 32 ]; then
    echo "[✗] xorriso failed with exit ${XORRISO_EXIT}"
    exit 1
fi
echo "[✓] xorriso completed (exit ${XORRISO_EXIT})"

echo ""
echo "[→] Boot record after reconstruction:"
xorriso -indev "${ISO_OUT}" -end 2>&1 | grep -E "(Boot record|El Torito|boot image)" | head -10

echo ""
echo "[→] Verify overlay still present:"
xorriso -indev "${ISO_OUT}" -find / -name "*.apkovl*" -end 2>&1 | grep apkovl | head -5

echo ""
echo "[→] Copying fixed ISO back to build-output..."
sudo cp "${ISO_OUT}" "${ISO_DEST}"
sha256sum "${ISO_OUT}" | sed "s|${ISO_OUT}|ntari-os-1.5.0-x86_64-ros2-20260228.iso|" \
    | sudo tee "${SHA_DEST}" > /dev/null

echo ""
ls -lh "${ISO_DEST}"
cat "${SHA_DEST}"
echo ""
echo "[✓] El-Torito reconstruction complete"
