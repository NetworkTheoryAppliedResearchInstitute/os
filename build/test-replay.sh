#!/bin/sh
# Test: does '-boot_image any replay' preserve the system area from indev?
# No set -e — we need to see the output even if xorriso exits non-zero.

ISO_IN="/workspace/build/build-output/ntari-os-1.5.0-x86_64-ros2-20260228.iso"
ISO_WORK="/tmp/test-replay.iso"
ISO_OUT="/tmp/test-replay-out.iso"

cp "${ISO_IN}" "${ISO_WORK}"
rm -f "${ISO_OUT}"

echo "[→] Input boot record:"
xorriso -indev "${ISO_WORK}" -end 2>&1 | grep -E "(Boot record)"

echo ""
echo "[→] Running replay with -abort_on FAILURE (SORRY won't abort)..."
xorriso \
    -abort_on FAILURE \
    -indev  "${ISO_WORK}" \
    -outdev "${ISO_OUT}" \
    -boot_image any replay \
    -map "${ISO_WORK}" "/_test_dummy_delete_me" \
    -rm "/_test_dummy_delete_me" \
    -commit \
    -end 2>&1
echo "xorriso exit: $?"

echo ""
if [ -f "${ISO_OUT}" ] && [ -s "${ISO_OUT}" ]; then
    echo "[✓] Output ISO exists: $(du -sh ${ISO_OUT} | cut -f1)"
    echo "[→] Output boot record:"
    xorriso -indev "${ISO_OUT}" -end 2>&1 | grep -E "(Boot record|El Torito)" | head -5
    file "${ISO_OUT}"
else
    echo "[✗] Output ISO missing or empty"
fi
