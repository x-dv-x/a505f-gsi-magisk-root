# Rooting the Samsung Galaxy A50 (SM-A505F) running a LineageOS GSI

Scripts and notes for rooting an **SM-A505F** (Exynos 9610 "a50") with **Magisk**, from
a Linux host (tested on Fedora), using **Heimdall** — no Windows/Odin required.

> This is a personal, legal modification of hardware I own. The bootloader was already
> unlocked. No firmware binaries, device images, or the Magisk APK are stored in this
> repo (see `.gitignore`); you supply your own.

## The key gotcha: this device has **no ramdisk in boot**

The A505F's stock `boot.img` is **system-as-root with no ramdisk** (the kernel mounts
system directly). Magisk's `magiskinit` lives in a ramdisk, so **it cannot run from the
boot partition** — flashing a Magisk-patched boot does nothing. Instead, Magisk must be
installed into the **recovery** partition, which *does* have a ramdisk.

Consequence — root is **boot-mode dependent**:

| How you boot | Result |
|---|---|
| Normal power-on | system, **no root** |
| `adb reboot recovery` / reboot-to-recovery menu | sets the BCB flag → **real recovery** → no root |
| **Hold `Volume Up` + `Power`** from power-off, release at the logo | system **WITH root** ✅ |

To get a rooted session: power off, then **Vol Up + Power**, release at the LineageOS logo.

## Requirements

Host packages (Fedora): `sudo dnf install heimdall lz4 unzip android-tools`
- `heimdall` — flash Samsung devices in download mode (Exynos has no fastboot)
- `lz4` — decompress Samsung `*.img.lz4`
- `adb` (android-tools) — talk to the booted phone
- Magisk app installed on the phone (the scripts pull its binaries off the device)

Phone: bootloader unlocked (`OEM unlocking` on), USB debugging on.

## Procedure

```bash
# 0. Obtain stock firmware matching your device and drop the zip in firmware/
#    (See "Getting firmware" below.) Then extract boot + recovery:
scripts/00-extract-images.sh
#    -> extracted/boot.img (kernel only, no ramdisk) and extracted/recovery.img

# 1. Patch recovery.img with Magisk (RECOVERYMODE=true), on the device, no root needed:
scripts/01-patch-recovery.sh
#    -> patched/magisk_recovery.img

# 2. Flash. ModemManager MUST be stopped first (see below):
sudo systemctl stop ModemManager
scripts/02-flash.sh --RECOVERY patched/magisk_recovery.img --BOOT extracted/boot.img
sudo systemctl start ModemManager

# 3. Power off, then Vol Up + Power -> boots system WITH root.
# 4. In the Magisk app: Settings -> Superuser access -> "Apps and ADB".
adb shell 'su -c id'   # -> uid=0(root) ... context=u:r:magisk:s0
```

### Reverting (remove root)
```bash
sudo systemctl stop ModemManager
scripts/02-flash.sh --RECOVERY extracted/recovery.img   # restore stock recovery
sudo systemctl start ModemManager
```

## Gotchas learned the hard way

- **ModemManager breaks Heimdall.** On Fedora, ModemManager probes the download-mode
  `ttyACM` port and steals it, giving `ERROR: Protocol initialisation failed!`. The first
  Heimdall command may slip through, then every later one fails. Stop ModemManager for the
  whole flashing session.
- **Heimdall sessions don't close cleanly.** Only the *first* command after entering
  download mode works reliably; re-enter download mode between commands.
- **Download mode needs a physical key press.** `adb reboot download` lands on a warning
  screen that exposes **no USB** until you press **Volume Up**.
- **Samsung's firmware CDN is geo-blocked** (`fota-cloud-dn.ospserver.net`, Akamai) — it
  returns HTTP 403 from some regions, so `samfirm`/`samloader` can fail with no firmware.
  Workarounds: a VPN, or a third-party mirror (browser download; captcha/login gated).
- **`.tar.md5` is just a tar with an MD5 appended** — `tar` extracts it fine but exits
  non-zero on the trailing bytes; the extract script tolerates that.
- Magisk's own on-device auto-detection sets `RECOVERYMODE` from the *running* ROM's props.
  A GSI advertising A/B/system-as-root can make it guess wrong, so the patch script sets the
  flags explicitly via `boot_patch.sh`.

## Getting firmware

Match your device's build (check `adb shell getprop ro.boot.bootloader`). Options:
- `samfirm` / `samloader` (direct from Samsung; blocked on some IPs — use a VPN), or
- a third-party firmware mirror via browser.

Extract `boot.img`/`recovery.img` from the `AP_*.tar.md5` inside the zip with
`scripts/00-extract-images.sh`.

## Layout

```
scripts/00-extract-images.sh   extract boot.img + recovery.img from a firmware zip
scripts/01-patch-recovery.sh   patch recovery.img with Magisk on-device (RECOVERYMODE=true)
scripts/02-flash.sh            heimdall flash helper (+ ModemManager guard)
firmware/  extracted/  patched/  magisk_apk/   # git-ignored working dirs (you populate)
```

## Credits / disclaimer

Magisk by topjohnwu. Heimdall by Glass Echidna / Benjamin Dobell. Rooting voids warranties
and can brick a device; proceed only on hardware you own and understand. No warranty.
