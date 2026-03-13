#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#

# Resolve busybox path dynamically (KSU / Magisk / system)
if [ -f /data/adb/ksu/bin/busybox ]; then
    BUSYBOX=/data/adb/ksu/bin/busybox
elif [ -f /data/adb/magisk/busybox ]; then
    BUSYBOX=/data/adb/magisk/busybox
else
    BUSYBOX="$(which busybox 2>/dev/null)"
fi
[ -n "$BUSYBOX" ] && alias busybox="$BUSYBOX"

(
# Wait until boot completed
until [ "$(resetprop sys.boot_completed 2>/dev/null || getprop sys.boot_completed)" = "1" ] &&
[ -d /sdcard ]; do
    sleep 10
done

# GMS components
GMS="com.google.android.gms"
GC1="auth.managed.admin.DeviceAdminReceiver"
GC2="mdm.receivers.MdmDeviceAdminReceiver"
NLL="/dev/null"

# Disable collective device administrators
for U in $(ls /data/user 2>/dev/null); do
    for C in $GC1 $GC2; do
        pm disable --user $U "$GMS/$GMS.$C" > $NLL 2>&1
    done
done

# Add GMS to battery optimization (remove from Doze whitelist)
dumpsys deviceidle whitelist -com.google.android.gms > $NLL 2>&1

exit 0
) &