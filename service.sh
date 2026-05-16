#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#

if [ -f /data/adb/ksu/bin/busybox ]; then
    BUSYBOX=/data/adb/ksu/bin/busybox
elif [ -f /data/adb/magisk/busybox ]; then
    BUSYBOX=/data/adb/magisk/busybox
else
    BUSYBOX="$(which busybox 2>/dev/null)"
fi
[ -n "$BUSYBOX" ] && alias busybox="$BUSYBOX"

(
    until [ "$(resetprop sys.boot_completed 2>/dev/null || getprop sys.boot_completed)" = "1" ] &&
          [ -d /sdcard ]; do
        sleep 10
    done

    GMS="com.google.android.gms"
    GC1="auth.managed.admin.DeviceAdminReceiver"
    GC2="mdm.receivers.MdmDeviceAdminReceiver"
    NLL="/dev/null"

    # Disable GMS device admin receivers for all users
    for U in $(ls /data/user 2>/dev/null); do
        for C in $GC1 $GC2; do
            pm disable --user "$U" "$GMS/$GMS.$C" > $NLL 2>&1
        done
    done

    # Remove GMS from user-tier deviceidle whitelist
    dumpsys deviceidle whitelist -"$GMS" > $NLL 2>&1

    # Remove GMS from system-tier whitelist (Android 12+)
    # Falls back silently if the sub-command is unavailable on older builds.
    cmd deviceidle sys-whitelist -"$GMS" > $NLL 2>&1

    # Remove GMS from except-idle (light-doze) whitelist (best-effort)
    cmd deviceidle except-idle-whitelist -"$GMS" > $NLL 2>&1

    # Always keep GSF in the whitelist so FCM/push notifications reach other apps
    dumpsys deviceidle whitelist +com.google.android.gsf > $NLL 2>&1

    # Process user-defined exemptions from exemptions.conf
    CONF="/data/adb/modules/universal-gms-doze/exemptions.conf"
    if [ -f "$CONF" ]; then
        while IFS= read -r PKG; do
            [ -z "$PKG" ] && continue
            dumpsys deviceidle whitelist +"$PKG" > $NLL 2>&1
            cmd appops set "$PKG" RUN_IN_BACKGROUND allow > $NLL 2>&1
            cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND allow > $NLL 2>&1
        done < "$CONF"
    fi

    # Clear cached GMS data that may hold stale whitelist state.
    # Runs unconditionally -- not gated on exemptions.conf.
    cd /data/data
    find . -type f -name '*gms*' -delete > $NLL 2>&1

    exit 0
) &