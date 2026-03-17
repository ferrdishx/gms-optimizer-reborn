#!/system/bin/sh
#
# Universal GMS Doze - DEBUG BUILD
# Logs everything to /data/adb/modules/universal-gms-doze/debug.log
#

LOG="/data/adb/modules/universal-gms-doze/debug.log"
mkdir -p "$(dirname $LOG)"

(
until [ "$(resetprop sys.boot_completed 2>/dev/null || getprop sys.boot_completed)" = "1" ]; do
    sleep 10
done

echo "========================================"
echo " UGD DEBUG - service.sh"
echo " $(date)"
echo "========================================"

# ── Busybox ───────────────────────────────────────────────────
if [ -f /data/adb/ksu/bin/busybox ]; then
    BUSYBOX=/data/adb/ksu/bin/busybox
elif [ -f /data/adb/magisk/busybox ]; then
    BUSYBOX=/data/adb/magisk/busybox
else
    BUSYBOX="$(which busybox 2>/dev/null)"
fi
echo "[ENV] busybox: ${BUSYBOX:-not found}"
echo "[ENV] Device: $(getprop ro.product.device)"
echo "[ENV] ROM: $(getprop ro.build.display.id)"
echo "[ENV] Android: $(getprop ro.build.version.release)"
echo "[ENV] Kernel: $(uname -r)"
echo "[ENV] SELinux: $(getenforce 2>/dev/null || echo unknown)"

# ── Partition mounts ──────────────────────────────────────────
echo "[PARTITIONS] Mount state at boot:"
mount | grep -E "/(system|product|vendor|system_ext)" | head -20
echo "[PARTITIONS] Symlink state:"
for P in /system/product /product /system/vendor /vendor /system/system_ext /system_ext; do
    if [ -L "$P" ]; then
        echo "  $P -> $(readlink $P) [SYMLINK]"
    elif [ -d "$P" ]; then
        echo "  $P [DIR]"
    fi
done

# ── Bind mount state ──────────────────────────────────────────
echo "[BIND] /proc/mounts entries for google.xml / sysconfig:"
cat /proc/mounts | grep -E "google|sysconfig|product" | head -10

echo "[BIND] google.xml state at runtime:"
for F in /product/etc/sysconfig/google.xml /system/etc/sysconfig/google.xml; do
    if [ -f "$F" ]; then
        echo "  FILE: $F"
        echo "  GMS entries:"
        grep -E "com.google.android.gms" "$F" 2>/dev/null || echo "  (none — correctly patched)"
        echo "  Is bind mounted:"
        cat /proc/mounts | grep "$F" || echo "  (no bind mount)"
        echo "  Inode: $(stat -c '%i' $F 2>/dev/null)"
    fi
done

echo "[BIND] Module patched/ directory:"
ls -la /data/adb/modules/universal-gms-doze/patched/ 2>/dev/null || echo "  (not found)"
for F in /data/adb/modules/universal-gms-doze/patched/*.xml 2>/dev/null; do
    [ -f "$F" ] || continue
    echo "  FILE: $F"
    echo "  GMS entries:"
    grep -E "com.google.android.gms" "$F" 2>/dev/null || echo "  (none — correctly patched)"
done

# ── Module state ──────────────────────────────────────────────
echo "[MODULE] Module directory contents:"
ls -laR /data/adb/modules/universal-gms-doze/ 2>/dev/null | head -40

echo "[MODULE] google.xml in module:"
find /data/adb/modules/universal-gms-doze/ -name "google.xml" 2>/dev/null | while read F; do
    echo "  FOUND: $F"
    grep -E "com.google.android.gms" "$F" || echo "  (none — correctly patched)"
done

echo "[MODULE] Metamodule mnt (if exists):"
for MNT in /data/adb/metamodule/mnt /data/adb/mountify/mnt; do
    if [ -d "$MNT/universal-gms-doze" ]; then
        echo "  $MNT/universal-gms-doze:"
        find "$MNT/universal-gms-doze" -name "google.xml" 2>/dev/null | while read F; do
            echo "    FOUND: $F"
            grep -E "com.google.android.gms" "$F" || echo "    (none — correctly patched)"
        done
    fi
done

# ── Doze whitelist ────────────────────────────────────────────
GMS="com.google.android.gms"
GC1="auth.managed.admin.DeviceAdminReceiver"
GC2="mdm.receivers.MdmDeviceAdminReceiver"
NLL="/dev/null"

echo "[DOZE] Removing GMS from whitelist..."
RESULT=$(dumpsys deviceidle whitelist -com.google.android.gms 2>&1)
echo "  result=$RESULT"

echo "[DOZE] Adding GSF to whitelist (required for FCM during Doze)..."
RESULT_GSF=$(dumpsys deviceidle whitelist +com.google.android.gsf 2>&1)
echo "  result=$RESULT_GSF"

echo "[DOZE] Disabling device administrators..."
for U in $(ls /data/user 2>/dev/null); do
    for C in $GC1 $GC2; do
        R=$(pm disable --user $U "$GMS/$GMS.$C" 2>&1)
        echo "  user=$U component=$C result=$R"
    done
done

# ── Re-apply exemptions ───────────────────────────────────────
CONF="/data/adb/modules/universal-gms-doze/exemptions.conf"
if [ -f "$CONF" ]; then
    echo "[EXEMPT] Re-applying from $CONF:"
    while IFS= read -r PKG; do
        [ -z "$PKG" ] && continue
        R1=$(dumpsys deviceidle whitelist +$PKG 2>&1)
        R2=$(cmd appops set $PKG RUN_IN_BACKGROUND allow 2>&1)
        R3=$(cmd appops set $PKG RUN_ANY_IN_BACKGROUND allow 2>&1)
        echo "  $PKG | whitelist=$R1 | bg=$R2 | anybg=$R3"
    done < "$CONF"
    echo "[EXEMPT] Clearing GMS cache..."
    cd /data/data && find . -type f -name '*gms*' -delete
else
    echo "[EXEMPT] No exemptions.conf found"
fi

# ── Final GMS state ───────────────────────────────────────────
echo "[RESULT] GMS optimization status:"
STATUS=$(dumpsys deviceidle whitelist 2>/dev/null | grep com.google.android.gms | head -1)
if [ -z "$STATUS" ]; then
    echo "  ✓ GMS is OPTIMIZED"
else
    echo "  ✗ GMS is NOT OPTIMIZED: $STATUS"
fi

echo "[RESULT] Full Doze whitelist:"
dumpsys deviceidle whitelist 2>/dev/null

echo "[RESULT] GMS processes running:"
ps -A 2>/dev/null | grep com.google.android.gms || ps 2>/dev/null | grep com.google.android.gms

echo "[RESULT] Doze mState:"
dumpsys deviceidle 2>/dev/null | grep -E "mState|Whitelist|com.google.android.gms" | head -20

echo "[RESULT] GMS package info:"
pm dump com.google.android.gms 2>/dev/null | grep -E "versionName|enabled|stopped|suspended|userId" | head -20

echo "[RESULT] GMS DeviceAdminReceiver state:"
pm query-receivers --components -a android.app.action.DEVICE_ADMIN_ENABLED 2>/dev/null | grep gms

echo "[DEBUG] service.sh completed. $(date)"
echo "========================================"
) >> "$LOG" 2>&1 &