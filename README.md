# Universal GMS Doze

## Overview
- Patches Google Play services app and certain processes/services to be able to use battery optimization
- Support API 23 or later
- Support Magisk, KernelSU, and APatch root implementations
- WebUI available

## WebUI
The module includes a built-in WebUI accessible from the KernelSU module page.

Features:
- GMS optimization status indicator
- Fix delayed notifications (clears GMS cache)
- Find My Device toggle (enable/disable)
- Force re-apply optimization

> **Note:** This is an unofficial fork of [gloeyisk/universal-gms-doze](https://github.com/gloeyisk/universal-gms-doze).
> The original project appears to be unmaintained. This fork only attempts to adapt compatibility
> for newer Android versions (15+) and KernelSU. No new features are intended.

> **KernelSU 3.x (32302+) users:** KernelSU 3.x introduced a new [Metamodule](https://kernelsu.org/guide/metamodule.html) system. Without a metamodule installed, **modules will NOT be mounted**. Before installing this module, you must first install [meta-overlayfs](https://github.com/KernelSU-Modules-Repo/meta-overlayfs/releases) or another compatible metamodule.
>
> **KernelSU legacy (22091 and below):** Works out of the box, no metamodule required.

## Download Links
- [GitHub Releases](https://github.com/MarsPatrick/universal-gms-doze/releases)

## Troubleshooting
- Command-line for check optimization (with module installed):
```
> su
> gmsc
```
- Command-line for check optimization (in general):   
There's a line written `Whitelist (except idle) system apps:` and if `com.google.android.gms` line does not exist it means Google Play services is optimized.
```
> su
> dumpsys deviceidle
```
- Command-line for fix delayed incoming messages issue:   
If the issue still persists, move the app to Not Optimized battery usage.
```
> su
> cd /data/data
> find . -type f -name '*gms*' -delete
```
- Command-line for disable Find My Device (optional):
```
> su
> pm disable com.google.android.gms/com.google.android.gms.mdm.receivers.MdmDeviceAdminReceiver
```

## Credits
- [gloeyisk](https://github.com/gloeyisk/universal-gms-doze) / Original author
- topjohnwu / Magisk - Magisk Module Template
- JumbomanXDA, MrCarb0n / Script fixer and helper

## Extras (Original Author)
- Donations: [PayPal](https://paypal.me/gloeyisk) - [LiberaPay](https://liberapay.com/gloeyisk) - [Ko-fi](https://ko-fi.com/gloeyisk)
- Support Thread: [XDA Developers](https://forum.xda-developers.com/apps/magisk/module-universal-gms-doze-t3853710)