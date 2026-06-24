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
    MOD="/data/adb/modules/gms-optimizer-reborn"

    PROFILE="balanced"
    [ -f "$MOD/profile.conf" ] && PROFILE="$(cat "$MOD/profile.conf" 2>/dev/null | tr -d '[:space:]')"

    for U in $(ls /data/user 2>/dev/null); do
        for C in $GC1 $GC2; do
            pm disable --user "$U" "$GMS/$GMS.$C" > $NLL 2>&1
        done
    done

    dumpsys deviceidle whitelist +com.google.android.gsf > $NLL 2>&1

    case "$PROFILE" in
        aggressive)
            dumpsys deviceidle whitelist -"$GMS" > $NLL 2>&1
            cmd deviceidle sys-whitelist -"$GMS" > $NLL 2>&1
            cmd deviceidle except-idle-whitelist -"$GMS" > $NLL 2>&1
            cmd appops set "$GMS" RUN_IN_BACKGROUND deny > $NLL 2>&1
            cmd appops set "$GMS" RUN_ANY_IN_BACKGROUND deny > $NLL 2>&1
            cmd appops set "$GMS" SCHEDULE_EXACT_ALARM deny > $NLL 2>&1
            cmd appops set "$GMS" WAKE_LOCK restrict > $NLL 2>&1
            ;;
        gaming)
            dumpsys deviceidle whitelist +"$GMS" > $NLL 2>&1
            cmd deviceidle sys-whitelist +"$GMS" > $NLL 2>&1
            cmd appops set "$GMS" RUN_IN_BACKGROUND allow > $NLL 2>&1
            cmd appops set "$GMS" RUN_ANY_IN_BACKGROUND allow > $NLL 2>&1
            cmd appops set "$GMS" SCHEDULE_EXACT_ALARM allow > $NLL 2>&1
            cmd appops set "$GMS" WAKE_LOCK allow > $NLL 2>&1
            ;;
        *)
            dumpsys deviceidle whitelist -"$GMS" > $NLL 2>&1
            cmd deviceidle sys-whitelist -"$GMS" > $NLL 2>&1
            cmd deviceidle except-idle-whitelist -"$GMS" > $NLL 2>&1
            cmd appops set "$GMS" RUN_IN_BACKGROUND default > $NLL 2>&1
            cmd appops set "$GMS" RUN_ANY_IN_BACKGROUND default > $NLL 2>&1
            cmd appops set "$GMS" SCHEDULE_EXACT_ALARM default > $NLL 2>&1
            cmd appops set "$GMS" WAKE_LOCK default > $NLL 2>&1
            ;;
    esac

    if [ -f "$MOD/exemptions.conf" ]; then
        while IFS= read -r PKG; do
            [ -z "$PKG" ] && continue
            dumpsys deviceidle whitelist +"$PKG" > $NLL 2>&1
            cmd appops set "$PKG" RUN_IN_BACKGROUND allow > $NLL 2>&1
            cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND allow > $NLL 2>&1
        done < "$MOD/exemptions.conf"
    fi

    exit 0
) &
