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
    until [ "$(resetprop sys.boot_completed 2>/dev/null || getprop sys.boot_completed)" = "1" ] \
       && [ -d /sdcard ]; do
        sleep 10
    done

    GMS="com.google.android.gms"
    GSF="com.google.android.gsf"
    GC1="auth.managed.admin.DeviceAdminReceiver"
    GC2="mdm.receivers.MdmDeviceAdminReceiver"
    N="/dev/null"
    MOD="/data/adb/modules/gms-optimizer-reborn"

    PROFILE="balanced"
    [ -f "$MOD/profile.conf" ] && PROFILE="$(cat "$MOD/profile.conf" 2>/dev/null | tr -d '[:space:]')"

    for U in $(ls /data/user 2>/dev/null); do
        pm disable --user "$U" "$GMS/$GMS.$GC1" > $N 2>&1
        pm disable --user "$U" "$GMS/$GMS.$GC2" > $N 2>&1
    done

    dumpsys deviceidle whitelist +"$GSF" > $N 2>&1

    case "$PROFILE" in
        aggressive)
            dumpsys deviceidle whitelist -"$GMS" > $N 2>&1
            cmd deviceidle whitelist -"$GMS" > $N 2>&1
            cmd deviceidle sys-whitelist -"$GMS" > $N 2>&1
            cmd deviceidle except-idle-whitelist -"$GMS" > $N 2>&1
            cmd appops set "$GMS" RUN_IN_BACKGROUND deny > $N 2>&1
            cmd appops set "$GMS" RUN_ANY_IN_BACKGROUND deny > $N 2>&1
            cmd appops set "$GMS" SCHEDULE_EXACT_ALARM deny > $N 2>&1
            cmd appops set "$GMS" WAKE_LOCK restrict > $N 2>&1
            ;;
        gaming)
            dumpsys deviceidle whitelist +"$GMS" > $N 2>&1
            cmd deviceidle whitelist +"$GMS" > $N 2>&1
            cmd deviceidle sys-whitelist +"$GMS" > $N 2>&1
            cmd appops set "$GMS" RUN_IN_BACKGROUND allow > $N 2>&1
            cmd appops set "$GMS" RUN_ANY_IN_BACKGROUND allow > $N 2>&1
            cmd appops set "$GMS" SCHEDULE_EXACT_ALARM allow > $N 2>&1
            cmd appops set "$GMS" WAKE_LOCK allow > $N 2>&1
            ;;
        *)
            dumpsys deviceidle whitelist -"$GMS" > $N 2>&1
            cmd deviceidle whitelist -"$GMS" > $N 2>&1
            cmd deviceidle sys-whitelist -"$GMS" > $N 2>&1
            cmd deviceidle except-idle-whitelist -"$GMS" > $N 2>&1
            cmd appops set "$GMS" RUN_IN_BACKGROUND default > $N 2>&1
            cmd appops set "$GMS" RUN_ANY_IN_BACKGROUND default > $N 2>&1
            cmd appops set "$GMS" SCHEDULE_EXACT_ALARM default > $N 2>&1
            cmd appops set "$GMS" WAKE_LOCK default > $N 2>&1
            ;;
    esac

    if [ -f "$MOD/exemptions.conf" ]; then
        while IFS= read -r PKG; do
            [ -z "$PKG" ] && continue
            dumpsys deviceidle whitelist +"$PKG" > $N 2>&1
            cmd appops set "$PKG" RUN_IN_BACKGROUND allow > $N 2>&1
            cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND allow > $N 2>&1
        done < "$MOD/exemptions.conf"
    fi

    exit 0
) &
