<div align="center">

# GMS Optimizer Reborn

**Forces Google Play Services into battery optimization, enabling real Doze mode savings.**

[![GitHub Release](https://img.shields.io/github/v/release/ferrdishx/universal-gms-doze?style=for-the-badge&color=00ff9d&labelColor=0a0a0f)](https://github.com/ferrdishx/universal-gms-doze/releases)
[![License](https://img.shields.io/github/license/ferrdishx/universal-gms-doze?style=for-the-badge&color=00ff9d&labelColor=0a0a0f)](LICENSE)
[![Android](https://img.shields.io/badge/Android-6.0%2B-00ff9d?style=for-the-badge&labelColor=0a0a0f)](https://github.com/ferrdishx/universal-gms-doze/releases)

</div>

---

## What It Does

By default, Android whitelists Google Play Services from battery optimization, preventing Doze mode from working properly. This module removes that exemption system-wide, patches relevant sysconfig XMLs, and ensures the state persists across reboots.

- Patches sysconfig XML files across all partitions
- Removes GMS from both user-tier and system-tier Doze whitelists
- Persists changes via `deviceidle.xml` injection on every boot
- Keeps Google Services Framework (GSF) whitelisted for push notifications
- Disables Find My Device admin receivers
- Includes `gmsc` binary for quick status check

---

## Requirements

| | |
|---|---|
| Android | 6.0+ (API 23+) |
| Root | Magisk, KernelSU or APatch |

> **KernelSU 3.x (32302+):** Requires [meta-overlayfs](https://github.com/KernelSU-Modules-Repo/meta-overlayfs/releases) or another compatible metamodule installed first.

---

## Installation

1. Download the latest `.zip` from [Releases](https://github.com/ferrdishx/universal-gms-doze/releases)
2. Open **Magisk / KernelSU / APatch**
3. Tap **Install from storage** and select the zip
4. Reboot

> Installation from recovery is **not supported**.

---

## WebUI

Available directly from the KernelSU module page.

| Feature | Description |
|---|---|
| Status | Shows whether GMS is currently optimized |
| Fix Notifications | Clears GMS cache to resolve delayed messages |
| Find My Device | Toggle to disable/enable the admin receiver |
| Force Re-apply | Reapplies optimization without rebooting |

---

## Verification

Run in a root shell:

```sh
gmsc
```

Or check manually:

```sh
dumpsys deviceidle
```

Look for the `Whitelist (except idle) system apps:` section — if `com.google.android.gms` is absent, it's optimized.

---

## Exemptions

To whitelist specific packages from Doze (e.g. messaging apps), create:

```
/data/adb/modules/gms-optimizer-reborn/exemptions.conf
```

One package name per line:

```
com.whatsapp
com.telegram.messenger
```

---

## Troubleshooting

**Delayed notifications after install**

```sh
su
cd /data/data
find . -type f -name '*gms*' -delete
```

Or use the **Fix Notifications** button in the WebUI.

**Disable Find My Device manually**

```sh
su -c "pm disable com.google.android.gms/com.google.android.gms.mdm.receivers.MdmDeviceAdminReceiver"
```

---

## Credits

- [gloeyisk](https://github.com/gloeyisk/universal-gms-doze) — original author
- [MarsPatrick](https://github.com/MarsPatrick/universal-gms-doze) — Android 15+ & KernelSU compatibility
- topjohnwu — Magisk Module Template

---

<div align="center">
<sub>Fork of MarsPatrick/universal-gms-doze · GPL-2.0</sub>
</div>
