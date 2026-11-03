#!/usr/bin/env bash
# Patch the stock recovery.img with Magisk (RECOVERYMODE=true) ON the connected device,
# using boot_patch.sh + the arm64 binaries pulled straight from the installed Magisk app.
# No root required on the phone; produces patched/magisk_recovery.img.
#
# Prereqs: Magisk app installed on the phone; `adb` sees the device; extracted/recovery.img exists.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p magisk_apk/payload patched
IMG="${1:-extracted/recovery.img}"
[ -f "$IMG" ] || { echo "Image not found: $IMG (run scripts/00-extract-images.sh first)"; exit 1; }

adb get-state >/dev/null 2>&1 || { echo "No adb device. Connect the phone (USB debugging on)."; exit 1; }

echo "[*] Pulling Magisk APK from the device..."
APK=$(adb shell pm path com.topjohnwu.magisk | sed 's/package://; s/\r//' | head -1)
[ -n "$APK" ] || { echo "Magisk app not installed on the phone."; exit 1; }
adb pull "$APK" magisk_apk/magisk.apk >/dev/null

echo "[*] Extracting arm64 binaries + patch scripts from the APK..."
cd magisk_apk
unzip -o -j magisk.apk \
  assets/boot_patch.sh assets/util_functions.sh assets/addon.d.sh \
  lib/arm64-v8a/libmagiskboot.so lib/arm64-v8a/libmagiskinit.so \
  lib/arm64-v8a/libmagisk.so lib/arm64-v8a/libinit-ld.so -d payload >/dev/null
cd payload
mv -f libmagiskboot.so magiskboot; mv -f libmagiskinit.so magiskinit
mv -f libmagisk.so magisk;        mv -f libinit-ld.so  init-ld
cd "$ROOT"

echo "[*] Pushing patch toolchain + image to /data/local/tmp/magiskpatch ..."
adb shell 'rm -rf /data/local/tmp/magiskpatch && mkdir -p /data/local/tmp/magiskpatch'
adb push magisk_apk/payload/magiskboot magisk_apk/payload/magiskinit \
         magisk_apk/payload/magisk     magisk_apk/payload/init-ld \
         magisk_apk/payload/boot_patch.sh magisk_apk/payload/util_functions.sh \
         magisk_apk/payload/addon.d.sh "$IMG" /data/local/tmp/magiskpatch/ >/dev/null
IMGNAME=$(basename "$IMG")

# PREINITDEVICE: let magisk auto-detect, or override via env before running this script.
: "${PREINITDEVICE:=$(adb shell 'cd /data/local/tmp/magiskpatch && chmod 755 magisk && ./magisk --preinit-device 2>/dev/null' | tr -d '\r')}"
echo "[*] Patching on device: RECOVERYMODE=true KEEPVERITY=true PREINITDEVICE=${PREINITDEVICE:-auto}"
adb shell "cd /data/local/tmp/magiskpatch && chmod 755 magiskboot magiskinit magisk init-ld *.sh && \
  KEEPVERITY=true KEEPFORCEENCRYPT=false RECOVERYMODE=true PREINITDEVICE='${PREINITDEVICE}' \
  sh boot_patch.sh $IMGNAME" 2>&1 | tail -6

echo "[*] Pulling patched image -> patched/magisk_recovery.img"
adb pull /data/local/tmp/magiskpatch/new-boot.img patched/magisk_recovery.img >/dev/null
adb shell 'rm -rf /data/local/tmp/magiskpatch'
ls -la patched/magisk_recovery.img; file patched/magisk_recovery.img
