# Universal GMS Doze

## Overview
- Patches Google Play services app and certain processes/services to be able to use battery optimization
- Support API 23 or later
- Support Magisk, KernelSU, and APatch root implementations

> **Note:** This is an unofficial fork of [gloeyisk/universal-gms-doze](https://github.com/gloeyisk/universal-gms-doze).
> The original project appears to be unmaintained. This fork only attempts to adapt compatibility
> for newer Android versions (15+) and KernelSU. No new features are intended.

> **KernelSU compatibility note:** Tested working on KernelSU **22091**. Version **3.1.0 (32302)** has known LKM loading issues on Pixel 7 Pro (and possibly other devices) with Android 15 / kernel 6.1.99, causing modules to not mount. If you experience issues with module mounting, downgrade KernelSU to 22091.

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