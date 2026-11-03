#!/usr/bin/env bash
# Flash images to a Samsung device in Download mode with Heimdall (Exynos = no fastboot).
# Usage examples:
#   scripts/02-flash.sh --RECOVERY patched/magisk_recovery.img --BOOT extracted/boot.img
#   scripts/02-flash.sh --RECOVERY extracted/recovery.img          # revert to stock recovery
#
# IMPORTANT on Fedora/Linux: ModemManager grabs the download-mode serial port and causes
# Heimdall "Protocol initialisation failed!". Stop it first:  sudo systemctl stop ModemManager
# (re-enable after:  sudo systemctl start ModemManager)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
[ "$#" -ge 2 ] || { echo "Usage: $0 --PARTITION image [--PARTITION image ...]"; exit 1; }

if systemctl is-active --quiet ModemManager 2>/dev/null; then
  echo "!! ModemManager is ACTIVE — Heimdall will likely fail. Stop it first:"
  echo "   sudo systemctl stop ModemManager"
  exit 1
fi

echo "[*] Rebooting device to download mode (press VOLUME UP on the warning screen)..."
adb reboot download 2>/dev/null || echo "   (device not in adb; put it in download mode manually)"
echo "[*] Waiting for download-mode USB (04e8:685d)... press VOL UP now"
for i in $(seq 1 150); do
  lsusb 2>/dev/null | grep -qiE "04e8:685d|04e8:68c3|04e8:6601" && break
  sleep 1
done
heimdall detect >/dev/null 2>&1 || { echo "No download-mode device detected."; exit 1; }
echo "[*] Flashing: heimdall flash $*"
heimdall flash "$@"
echo "[*] Done. For a no-ramdisk device, boot with VOL UP + POWER to get root (see README)."
