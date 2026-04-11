#!/system/bin/sh
#
# Universal GMS Doze - DEBUG BUILD
# Logs everything to module folder debug.log
#
MODDIR=${0%/*}
LOG="$MODDIR/debug.log"
mkdir -p "$(dirname $LOG)"
exec >> "$LOG" 2>&1
set -x
echo "========================================"
echo " UGD DEBUG - post-fs-data.sh"
echo " $(date)"
echo "========================================"
NULL="/dev/null"
GMS0="\"com.google.android.gms\""
STR1="allow-unthrottled-location package=$GMS0"
STR2="allow-ignore-location-settings package=$GMS0"
STR3="allow-in-power-save package=$GMS0"
STR4="allow-in-data-usage-save package=$GMS0"
echo "[PARTITIONS] Mount state at post-fs-data:"
mount | grep -E "/(system|product|vendor|system_ext)" | head -20
echo "[PARTITIONS] Symlink check:"
for P in /system/product /product /system/vendor /vendor /system/system_ext /system_ext; do
    if [ -L "$P" ]; then
        echo "  $P -> $(readlink $P) [SYMLINK]"
    elif [ -d "$P" ]; then
        echo "  $P [DIR]"
    else
        echo "  $P [NOT FOUND]"
    fi
done
echo "[XML-STATE] google.xml state BEFORE bind mount:"
for F in /product/etc/sysconfig/google.xml /system/etc/sysconfig/google.xml /system_ext/etc/sysconfig/google.xml; do
    if [ -f "$F" ]; then
        echo "  EXISTS: $F"
        echo "  Inode: $(stat -c '%i' "$F" 2>/dev/null)"
        echo "  GMS entries:"
        grep -E "com.google.android.gms" "$F" 2>/dev/null || echo "  (none)"
        echo "  Full content:"
        cat "$F"
    else
        echo "  NOT FOUND: $F"
    fi
done
echo "[MOD-XML] Searching conflicting module XMLs..."
find /data/adb/* -type f -iname "*.xml" -print 2>/dev/null |
while IFS= read -r XML; do
    if grep -qE "$STR1|$STR2|$STR3|$STR4" "$XML" 2>/dev/null; then
        echo "[MOD-XML] FOUND conflicting: $XML"
        echo "[MOD-XML] BEFORE:"
        cat "$XML"
        sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" "$XML"
        echo "[MOD-XML] AFTER:"
        cat "$XML"
    fi
done
PATCH_DIR="$MODDIR/patched"
echo "[BIND] Creating patch dir: $PATCH_DIR"
mkdir -p "$PATCH_DIR"
for SRC in \
    /product/etc/sysconfig/google.xml \
    /system/etc/sysconfig/google.xml \
    /system_ext/etc/sysconfig/google.xml; do
    echo "[BIND] Checking: $SRC"
    if [ ! -f "$SRC" ]; then
        echo "[BIND]   NOT FOUND, skipping"
        continue
    fi
    if ! grep -qE "$STR1|$STR2|$STR3|$STR4" "$SRC" 2>/dev/null; then
        echo "[BIND]   No GMS entries found, skipping"
        continue
    fi
    FNAME="$(echo "$SRC" | tr '/' '_').xml"
    DST="$PATCH_DIR/$FNAME"
    echo "[BIND]   Copying $SRC -> $DST"
    cp -f "$SRC" "$DST"
    echo "[BIND]   Patching $DST"
    sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" "$DST"
    echo "[BIND]   Patched content:"
    cat "$DST"
    echo "[BIND]   Remaining GMS entries in patched file:"
    grep -E "com.google.android.gms" "$DST" 2>/dev/null || echo "[BIND]   (none - correctly patched)"
    echo "[BIND]   Attempting mount --bind $DST $SRC"
    mount --bind "$DST" "$SRC"
    MOUNT_RESULT=$?
    echo "[BIND]   mount result: $MOUNT_RESULT"
    if [ $MOUNT_RESULT -eq 0 ]; then
        echo "[BIND]   SUCCESS - verifying:"
        echo "[BIND]   Inode after bind (should differ from original):"
        stat -c '%i' "$SRC" 2>/dev/null
        echo "[BIND]   GMS entries in mounted file:"
        grep -E "com.google.android.gms" "$SRC" 2>/dev/null || echo "[BIND]   (none - bind mount working)"
        echo "[BIND]   /proc/mounts entry:"
        cat /proc/mounts | grep "$SRC" || echo "[BIND]   (not in /proc/mounts)"
    else
        echo "[BIND]   FAILED - mount --bind returned $MOUNT_RESULT"
        echo "[BIND]   Trying alternative: mount -o bind"
        mount -o bind "$DST" "$SRC"
        echo "[BIND]   Alternative mount result: $?"
    fi
done
echo "[BIND] Final /proc/mounts state:"
cat /proc/mounts | grep -E "google|sysconfig|product" | head -10
echo "[BIND] patched/ directory:"
ls -la "$PATCH_DIR" 2>/dev/null
echo "[DEBUG] post-fs-data.sh completed. $(date)"
echo "========================================"