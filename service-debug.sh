#!/system/bin/sh
#
# Universal GMS Doze - DEBUG BUILD
# Logs everything to /data/adb/modules/universal-gms-doze/debug.log
#

LOG="/data/adb/modules/universal-gms-doze/debug.log"
mkdir -p "$(dirname $LOG)"

(
# Wait for boot complete
until [ "$(resetprop sys.boot_completed 2>/dev/null || getprop sys.boot_completed)" = "1" ]; do
    sleep 10
done

echo "========================================"
echo " UGD DEBUG - service.sh"
echo " $(date)"
echo "========================================"

# Resolve busybox
if [ -f /data/adb/ksu/bin/busybox ]; then
    BUSYBOX=/data/adb/ksu/bin/busybox
elif [ -f /data/adb/magisk/busybox ]; then
    BUSYBOX=/data/adb/magisk/busybox
else
    BUSYBOX="$(which busybox 2>/dev/null)"
fi
echo "[DEBUG] busybox: ${BUSYBOX:-not found}"
[ -n "$BUSYBOX" ] && alias busybox="$BUSYBOX"

echo "[DEBUG] Boot complete. $(date)"
echo "[DEBUG] Device info:"
echo "  Device: $(getprop ro.product.device)"
echo "  ROM: $(getprop ro.build.display.id)"
echo "  Android: $(getprop ro.build.version.release)"
echo "  Kernel: $(uname -r)"

GMS="com.google.android.gms"
GC1="auth.managed.admin.DeviceAdminReceiver"
GC2="mdm.receivers.MdmDeviceAdminReceiver"
NLL="/dev/null"

echo "[DEBUG] Disabling device administrators..."
for U in $(ls /data/user 2>/dev/null); do
    for C in $GC1 $GC2; do
        RESULT=$(pm disable --user $U "$GMS/$GMS.$C" 2>&1)
        echo "  user=$U component=$C result=$RESULT"
    done
done

echo "[DEBUG] Removing GMS from Doze whitelist..."
RESULT=$(dumpsys deviceidle whitelist -com.google.android.gms 2>&1)
echo "  result=$RESULT"

echo "[DEBUG] Verifying GMS optimization status..."
STATUS=$(dumpsys deviceidle whitelist 2>/dev/null | grep com.google.android.gms | head -1)
if [ -z "$STATUS" ]; then
    echo "  GMS is OPTIMIZED (not in whitelist)"
else
    echo "  GMS is NOT OPTIMIZED: $STATUS"
fi

echo "[DEBUG] Full Doze whitelist:"
dumpsys deviceidle whitelist 2>/dev/null

echo "[DEBUG] GMS running processes:"
ps -A 2>/dev/null | grep com.google.android.gms || ps 2>/dev/null | grep com.google.android.gms

echo "[DEBUG] GMS battery optimization state:"
dumpsys deviceidle 2>/dev/null | grep -E "mState|Whitelist|com.google.android.gms" | head -20

echo "[DEBUG] GMS package info:"
pm dump com.google.android.gms 2>/dev/null | grep -E "versionName|enabled|stopped|suspended|userId" | head -20

echo "[DEBUG] GMS component states (DeviceAdminReceiver):"
pm query-receivers --components -a android.app.action.DEVICE_ADMIN_ENABLED 2>/dev/null | grep gms

echo "[DEBUG] service.sh completed. $(date)"
echo "========================================"
) >> "$LOG" 2>&1 &