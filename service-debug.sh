#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#
# DEBUG VERSION - appends to /data/adb/ugd_debug.log
#

DEBUG_LOG="/data/adb/ugd_debug.log"
mkdir -p "$(dirname "$DEBUG_LOG")"

dbg() { echo "[DBG][service][$(date '+%H:%M:%S')] $1" >> "$DEBUG_LOG"; }

if [ -f /data/adb/ksu/bin/busybox ]; then
    BUSYBOX=/data/adb/ksu/bin/busybox
    dbg "BusyBox: KSU ($BUSYBOX)"
elif [ -f /data/adb/magisk/busybox ]; then
    BUSYBOX=/data/adb/magisk/busybox
    dbg "BusyBox: Magisk ($BUSYBOX)"
else
    BUSYBOX="$(which busybox 2>/dev/null)"
    dbg "BusyBox: system (${BUSYBOX:-not found})"
fi
[ -n "$BUSYBOX" ] && alias busybox="$BUSYBOX"

(
    dbg "=== service.sh background subshell start ==="

    # Wait for boot
    WAIT_ITER=0
    until [ "$(resetprop sys.boot_completed 2>/dev/null || getprop sys.boot_completed)" = "1" ] &&
          [ -d /sdcard ]; do
        sleep 10
        WAIT_ITER=$((WAIT_ITER + 1))
        [ $((WAIT_ITER % 6)) -eq 0 ] && dbg "Still waiting for boot... (${WAIT_ITER}x10s)"
    done
    dbg "Boot completed after ~$((WAIT_ITER * 10))s"

    GMS="com.google.android.gms"
    GC1="auth.managed.admin.DeviceAdminReceiver"
    GC2="mdm.receivers.MdmDeviceAdminReceiver"
    NLL="/dev/null"

    # --- System state snapshot ---
    dbg "--- System state at boot ---"
    dbg "Android API: $(getprop ro.build.version.sdk)"
    dbg "Device: $(getprop ro.product.model) / $(getprop ro.product.device)"

    # --- Overlay/mount verification ---
    dbg "--- Overlay mount state ---"
    MODDIR="/data/adb/modules/universal-gms-doze"
    dbg "Module dir: $MODDIR"
    find "$MODDIR" -name "*.xml" 2>/dev/null | while read f; do
        dbg "  Overlay file: $f"
        # Check if corresponding system path is bind-mounted
        SYS_PATH="${f#$MODDIR}"
        dbg "  -> system path: $SYS_PATH"
        if [ -f "$SYS_PATH" ]; then
            OVERLAY_ACTIVE="NO"
            if grep -qE "com\.google\.android\.gms|allow-in-power-save" "$SYS_PATH" 2>/dev/null; then
                OVERLAY_ACTIVE="NO (GMS still in system file)"
            else
                OVERLAY_ACTIVE="YES (GMS absent from system file)"
            fi
            dbg "  -> Overlay active: $OVERLAY_ACTIVE"
        else
            dbg "  -> System path not found: $SYS_PATH"
        fi
    done
    dbg "--- end overlay state ---"

    # --- Whitelist BEFORE ---
    dbg "--- deviceidle whitelist BEFORE ---"
    dumpsys deviceidle whitelist 2>/dev/null >> "$DEBUG_LOG"
    dbg "--- end whitelist before ---"
    dbg "--- deviceidle full dump (relevant sections) BEFORE ---"
    dumpsys deviceidle 2>/dev/null | grep -A2 -B2 "$GMS" >> "$DEBUG_LOG"
    dbg "--- end deviceidle dump ---"

    # --- Device admin receivers ---
    dbg "--- Disabling device admin receivers ---"
    USERS="$(ls /data/user 2>/dev/null)"
    dbg "Users found: $USERS"
    for U in $USERS; do
        for C in $GC1 $GC2; do
            RESULT="$(pm disable --user "$U" "$GMS/$GMS.$C" 2>&1)"
            dbg "  pm disable --user $U $GMS/$GMS.$C -> $RESULT"
        done
    done
    dbg "--- end device admin ---"

    # --- Whitelist removal ---
    dbg "--- Removing GMS from whitelists ---"

    OUT="$(dumpsys deviceidle whitelist -"$GMS" 2>&1)"
    dbg "  user-tier removal: $OUT"

    OUT="$(cmd deviceidle sys-whitelist -"$GMS" 2>&1)"
    dbg "  sys-whitelist removal: $OUT"

    OUT="$(cmd deviceidle except-idle-whitelist -"$GMS" 2>&1)"
    dbg "  except-idle-whitelist removal: $OUT"

    # Keep GSF whitelisted
    OUT="$(dumpsys deviceidle whitelist +com.google.android.gsf 2>&1)"
    dbg "  GSF whitelist add: $OUT"

    dbg "--- end whitelist removal ---"

    # --- Whitelist AFTER ---
    dbg "--- deviceidle whitelist AFTER ---"
    dumpsys deviceidle whitelist 2>/dev/null >> "$DEBUG_LOG"
    dbg "--- end whitelist after ---"

    # --- GMS pm state ---
    dbg "--- GMS package state ---"
    pm dump "$GMS" 2>/dev/null | grep -E "enabled|disabled|stopped|pkgFlags|userId|receivers" >> "$DEBUG_LOG"
    dbg "--- end GMS package state ---"

    # --- Exemptions ---
    CONF="/data/adb/modules/universal-gms-doze/exemptions.conf"
    if [ -f "$CONF" ]; then
        dbg "--- Processing exemptions.conf ---"
        while IFS= read -r PKG; do
            [ -z "$PKG" ] && continue
            dbg "  Exempting: $PKG"
            OUT1="$(dumpsys deviceidle whitelist +"$PKG" 2>&1)"
            OUT2="$(cmd appops set "$PKG" RUN_IN_BACKGROUND allow 2>&1)"
            OUT3="$(cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND allow 2>&1)"
            dbg "    whitelist: $OUT1"
            dbg "    RUN_IN_BACKGROUND: $OUT2"
            dbg "    RUN_ANY_IN_BACKGROUND: $OUT3"
        done < "$CONF"
        dbg "--- end exemptions ---"
    else
        dbg "No exemptions.conf found"
    fi

    # --- GMS data cleanup ---
    dbg "--- GMS data file cleanup ---"
    cd /data/data
    GMS_FILES="$(find . -type f -name '*gms*' 2>/dev/null)"
    if [ -n "$GMS_FILES" ]; then
        dbg "Files found for deletion:"
        echo "$GMS_FILES" >> "$DEBUG_LOG"
        find . -type f -name '*gms*' -delete > $NLL 2>&1
        dbg "Deletion complete"
    else
        dbg "No GMS data files found"
    fi
    dbg "--- end GMS data cleanup ---"

    # --- deviceidle.xml final state ---
    DEVICEIDLE_XML="/data/system/deviceidle.xml"
    dbg "--- $DEVICEIDLE_XML final state ---"
    if [ -f "$DEVICEIDLE_XML" ]; then
        GMS_WL="$(grep -c "<wl n=\"$GMS\"" "$DEVICEIDLE_XML" 2>/dev/null || echo 0)"
        GMS_UNWL="$(grep -c "<un-wl n=\"$GMS\"" "$DEVICEIDLE_XML" 2>/dev/null || echo 0)"
        dbg "  <wl> count: $GMS_WL"
        dbg "  <un-wl> count: $GMS_UNWL"
    else
        dbg "  File not present"
    fi
    dbg "--- end deviceidle.xml state ---"

    dbg "=== service.sh complete ==="

    exit 0
) &