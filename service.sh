#!/system/bin/sh

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

    for U in $(ls /data/user 2>/dev/null); do
        for C in $GC1 $GC2; do
            pm disable --user "$U" "$GMS/$GMS.$C" > $NLL 2>&1
        done
    done

    dumpsys deviceidle whitelist -"$GMS" > $NLL 2>&1
    cmd deviceidle sys-whitelist -"$GMS" > $NLL 2>&1
    cmd deviceidle except-idle-whitelist -"$GMS" > $NLL 2>&1

    dumpsys deviceidle whitelist +com.google.android.gsf > $NLL 2>&1

    CONF="/data/adb/modules/gms-optimizer-reborn/exemptions.conf"
    if [ -f "$CONF" ]; then
        while IFS= read -r PKG; do
            [ -z "$PKG" ] && continue
            dumpsys deviceidle whitelist +"$PKG" > $NLL 2>&1
            cmd appops set "$PKG" RUN_IN_BACKGROUND allow > $NLL 2>&1
            cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND allow > $NLL 2>&1
        done < "$CONF"
    fi

    cd /data/data
    find . -type f -name '*gms*' -delete > $NLL 2>&1

    exit 0
) &
