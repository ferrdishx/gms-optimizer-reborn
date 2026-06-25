## Changelog

### 1.0.2
- **WebUI — Icons:** fixed icon clipping caused by img and letter avatar rendering side-by-side in flex container; letter is now cleared before the icon loads and restored on error
- **WebUI — App labels:** removed heuristic name guessing entirely; initial render uses only known labels from the built-in map, all other apps show their real name fetched via `aapt2`/`aapt` as they enter the viewport
- **WebUI — Search:** filter now uses real cached labels instead of the package name heuristic

### 1.0.1
- **WebUI — Status check:** fixed false "Not Optimized" on OEM ROMs (Samsung, Xiaomi) that keep GMS in the system-level Doze whitelist; status now checks only the user whitelist
- **WebUI — RAM metric:** now sums all GMS processes (gms, gms.ui, gms.unstable, gms.persistent, etc.) instead of only the main process PID
- **WebUI — Icons:** replaced slow APK extraction (unzip + base64) with native `ksu://icon/` URI; icons load instantly and work with adaptive icon formats
- **WebUI — App labels:** added lazy real-name resolution via `aapt2`/`aapt` for apps not in the built-in label map; falls back to package name heuristic if aapt is unavailable

### 1.0.0
- Rebranded as **GMS Optimizer Reborn** (fork of MarsPatrick/universal-gms-doze 1.9.10)
- All scripts rewritten without inline comments, English only
- **WebUI — 4 tabs:**
  - Home: live status with active profile name, surgical notification fix
  - Profiles: Balanced / Aggressive / Gaming — persisted via profile.conf, re-applied on boot
  - Exemptions: app list with letter avatars and friendly labels, auto-detect messaging apps
  - Logs: Doze state, install log and AppOps dump directly in the UI
- **Notification fix is now surgical:** force-stops GMS, runs pm trim-caches, targets only gcm/fcm database files instead of a broad find-delete
- **3 optimization profiles via AppOps:**
  - Balanced: whitelist removed, AppOps at default
  - Aggressive: additionally restricts WAKE_LOCK, SCHEDULE_EXACT_ALARM and background activity
  - Gaming: re-whitelists GMS and sets all AppOps to allow
- **Auto-detect Messaging:** scans installed packages and auto-exempts known messaging apps (WhatsApp, Telegram, Signal, Discord, Viber, etc.)
- **OxygenOS detection:** banner shown automatically with link to Frosty if OxygenOS is detected
- **JS security:** crypto.randomUUID() replaces Date.now() for KernelSU callback IDs
- service.sh reads profile.conf on boot and applies the correct AppOps commands
- module.json and updateJson point to new repository
