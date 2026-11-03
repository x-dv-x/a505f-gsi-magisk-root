#!/usr/bin/env bash
# Extract stock boot.img and recovery.img from a Samsung firmware zip.
# Usage: scripts/00-extract-images.sh [path/to/firmware.zip]
# Default: newest *.zip in firmware/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p extracted
ZIP="${1:-$(ls -S firmware/*.zip 2>/dev/null | head -1)}"
[ -n "${ZIP:-}" ] && [ -f "$ZIP" ] || { echo "No firmware zip found. Put one in firmware/ or pass a path."; exit 1; }
echo "[*] Firmware zip: $ZIP"

echo "[*] Extracting AP_*.tar.md5 from the zip..."
unzip -o "$ZIP" 'AP_*' -d extracted/ >/dev/null || unzip -o "$ZIP" -d extracted/ >/dev/null
AP=$(ls -S extracted/AP_*.tar.md5 extracted/AP_*.tar 2>/dev/null | head -1)
[ -n "${AP:-}" ] || { echo "No AP_*.tar(.md5) in the zip"; exit 1; }
echo "[*] AP: $AP"

# Samsung .tar.md5 = tar with an MD5 string appended; tar extracts fine but exits non-zero, so tolerate it.
for member in boot.img.lz4 recovery.img.lz4; do
  echo "[*] Extracting $member ..."
  tar -C extracted/ -xvf "$AP" "$member" 2>/dev/null || true
  base="${member%.lz4}"
  if [ -f "extracted/$member" ]; then
    lz4 -d -f "extracted/$member" "extracted/$base"
    echo "    -> extracted/$base"
  fi
done

echo "[*] Results:"
for f in boot.img recovery.img; do [ -f "extracted/$f" ] && { ls -la "extracted/$f"; file "extracted/$f"; }; done
echo
echo "NOTE: if 'file' shows boot.img as 'kernel' with NO ramdisk, this is a system-as-root"
echo "device: Magisk must go in RECOVERY (see scripts/01-patch-recovery.sh), not boot."
