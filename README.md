<div align="center">
  <img src="banner.png" alt="GMS Optimizer Reborn" width="100%">
</div>

<div align="center">

# GMS Optimizer Reborn

**Forces Google Play Services into battery optimization, enabling real Doze mode savings.**

[![GitHub Release](https://img.shields.io/github/v/release/ferrdishx/gms-optimizer-reborn?style=for-the-badge&color=00ff9d&labelColor=0a0a0f)](https://github.com/ferrdishx/gms-optimizer-reborn/releases/latest)
[![GitHub Downloads](https://img.shields.io/github/downloads/ferrdishx/gms-optimizer-reborn/total?style=for-the-badge&color=00ff9d&labelColor=0a0a0f)](https://github.com/ferrdishx/gms-optimizer-reborn/releases)
[![License](https://img.shields.io/github/license/ferrdishx/gms-optimizer-reborn?style=for-the-badge&color=00ff9d&labelColor=0a0a0f)](LICENSE)
[![Android](https://img.shields.io/badge/Android-6.0%2B-00ff9d?style=for-the-badge&labelColor=0a0a0f)](https://github.com/ferrdishx/gms-optimizer-reborn/releases/latest)

</div>

---

## What It Does

By default, Android whitelists Google Play Services from battery optimization, preventing Doze mode from working properly. GMS Optimizer Reborn removes that exemption system-wide, patches all relevant sysconfig XMLs across partitions, and ensures the state persists across every reboot.

- Patches sysconfig XML files across all system partitions
- Removes GMS from user-tier and system-tier Doze whitelists
- Persists changes via `deviceidle.xml` injection on every boot
- Keeps Google Services Framework (GSF) whitelisted for push notifications
- Disables Find My Device admin receivers
- Includes `gmsc` binary for quick terminal status check

---

## Requirements

| | |
|---|---|
| Android | 6.0+ (API 23+) |
| Root | Magisk, KernelSU or APatch |

> **KernelSU 3.x (32302+):** Requires [meta-overlayfs](https://github.com/KernelSU-Modules-Repo/meta-overlayfs/releases) or another compatible metamodule installed first.
>
> **OnePlus OxygenOS 16:** GMS modification may be blocked by the system. If optimization does not apply, try [Frosty](https://github.com/xizt159/Frosty) instead.

---

## Installation

1. Download the latest `.zip` from [Releases](https://github.com/ferrdishx/gms-optimizer-reborn/releases/latest)
2. Open **Magisk / KernelSU / APatch**
3. Tap **Install from storage** and select the zip
4. Reboot

> Installation from recovery is **not supported**.

---

## WebUI

Available directly from the KernelSU or APatch module page.

### Home

| Feature | Description |
|---|---|
| Optimization Status | Live GMS Doze status with active profile indicator |
| Fix Delayed Notifications | Surgically clears GMS cache, force-stops the process and deletes stale FCM/GCM database entries |
| Find My Device Toggle | Enable or disable the MdmDeviceAdminReceiver |
| Force Re-apply | Removes GMS from all Doze whitelists immediately without rebooting |

### Profiles

Three optimization profiles, persisted across reboots:

| Profile | Description |
|---|---|
| **Balanced** | Removes GMS from Doze whitelist, keeps AppOps at default. Recommended for daily use. |
| **Aggressive** | Additionally restricts background activity, WAKE_LOCK and SCHEDULE_EXACT_ALARM via AppOps. May cause notification delays. |
| **Gaming** | Temporarily re-whitelists GMS and sets all AppOps to allow. Switch back after your session. |

### Exemptions

- Full app list with real app names and icons, package search
- Toggle individual apps in or out of the Doze exemption list
- **Auto-detect Messaging** — automatically detects and exempts installed messaging apps (WhatsApp, Telegram, Signal, Discord and more)
- Changes are saved to `exemptions.conf` and re-applied on every boot

### Logs

Direct in-UI access to Doze state dump, install log and GMS AppOps output — no terminal needed.

---

## Verification

Run in a root shell:

```sh
gmsc
```

Or check manually:

```sh
dumpsys deviceidle whitelist
```

Look for `Whitelist user apps:` and `Whitelist (except idle) user apps:` — if `com.google.android.gms` is absent from both sections, optimization is active. OEM ROMs (Samsung, Xiaomi) may keep GMS in the system-level whitelist by design; the module targets the user-level whitelist which is what actually controls Doze behavior.

---

## Exemptions File

To manually whitelist packages from Doze, create:

```
/data/adb/modules/gms-optimizer-reborn/exemptions.conf
```

One package per line:

```
com.whatsapp
org.telegram.messenger
```

---

## Troubleshooting

**Delayed notifications after install**

Use the **Fix Delayed Notifications** button in the WebUI, or run:

```sh
su -c "am force-stop com.google.android.gms; pm trim-caches 999G"
```

**Disable Find My Device manually**

```sh
su -c "pm disable com.google.android.gms/com.google.android.gms.mdm.receivers.MdmDeviceAdminReceiver"
```

**Check optimization status**

```sh
su -c gmsc
```

---

## Credits

- [gloeyisk](https://github.com/gloeyisk/universal-gms-doze) — original author
- [MarsPatrick](https://github.com/MarsPatrick/universal-gms-doze) — Android 15+ & KernelSU compatibility base
- topjohnwu — Magisk Module Template

---

<div align="center">
<sub>GMS Optimizer Reborn · GPL-2.0 · <a href="https://github.com/ferrdishx/gms-optimizer-reborn">ferrdishx/gms-optimizer-reborn</a></sub>
</div>
