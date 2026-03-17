#!/system/bin/sh
#
# Universal GMS Doze - DEBUG BUILD
# Logs everything to module folder debug.log
#

LOG="/data/adb/modules/universal-gms-doze/debug.log"
if [ -d /data/adb/modules_update/universal-gms-doze ]; then
    LOG="/data/adb/modules_update/universal-gms-doze/debug.log"
fi
mkdir -p "$(dirname $LOG)"
exec >> "$LOG" 2>&1
set -x

echo "========================================"
echo " UGD DEBUG - customize.sh"
echo " $(date)"
echo "========================================"

# â”€â”€ Environment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
echo "[ENV] BOOTMODE=$BOOTMODE"
echo "[ENV] KSU=$KSU KSU_VER_CODE=$KSU_VER_CODE KSU_KERNEL_VER_CODE=$KSU_KERNEL_VER_CODE"
echo "[ENV] APATCH=$APATCH"
echo "[ENV] MAGISK_VER_CODE=$MAGISK_VER_CODE"
echo "[ENV] API=$API"
echo "[ENV] MODPATH=$MODPATH"
echo "[ENV] ARCH=$(uname -m)"
echo "[ENV] Kernel=$(uname -r)"
echo "[ENV] ROM=$(getprop ro.build.display.id)"
echo "[ENV] Android=$(getprop ro.build.version.release)"
echo "[ENV] Device=$(getprop ro.product.device)"
echo "[ENV] Brand=$(getprop ro.product.brand)"
echo "[ENV] Model=$(getprop ro.product.model)"
echo "[ENV] SDK=$(getprop ro.build.version.sdk)"
echo "[ENV] SELinux=$(getenforce 2>/dev/null || echo unknown)"

# â”€â”€ Partition layout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
echo "[PARTITIONS] Checking partition mounts..."
mount | grep -E "^/dev.*/(system|product|vendor|system_ext|my_|data)" | head -30
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

# â”€â”€ Metamodule detection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
echo "[METAMODULE] Checking metamodule state..."
for P in /data/adb/metamodule /data/adb/mountify /data/adb/magicmount /data/adb/hybridmount; do
    if [ -L "$P" ]; then
        echo "  $P -> $(readlink $P) [SYMLINK]"
    elif [ -d "$P" ]; then
        echo "  $P [DIR]"
        ls "$P" 2>/dev/null | head -5
    fi
done
echo "[METAMODULE] /data/adb contents:"
ls /data/adb/ 2>/dev/null

# â”€â”€ google.xml state BEFORE anything â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
echo "[XML-BEFORE] State of google.xml BEFORE any patching:"
for F in /product/etc/sysconfig/google.xml /system/etc/sysconfig/google.xml /system_ext/etc/sysconfig/google.xml; do
    if [ -f "$F" ]; then
        echo "  EXISTS: $F"
        echo "  GMS entries:"
        grep -E "com.google.android.gms" "$F" 2>/dev/null || echo "  (none)"
        echo "  Is bind mounted:"
        cat /proc/mounts | grep "$F" || echo "  (no)"
    fi
done

# â”€â”€ Fallback definitions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
if ! command -v ui_print >/dev/null 2>&1; then
    ui_print() { echo "[ui_print] $1"; }
fi
if ! command -v abort >/dev/null 2>&1; then
    abort() { ui_print "$1"; exit 1; }
fi
if ! command -v set_perm >/dev/null 2>&1; then
    set_perm() { chown $2:$3 "$1"; chmod $4 "$1"; }
fi
if ! command -v set_perm_recursive >/dev/null 2>&1; then
    set_perm_recursive() {
        find "$1" -type d -exec chmod $4 {} \;
        find "$1" -type f -exec chmod $5 {} \;
        find "$1" -exec chown $2:$3 {} \;
    }
fi

[ -z "$MODPATH" ] && MODPATH="/data/adb/modules_update/universal-gms-doze"
[ -z "$API" ] && API="$(getprop ro.build.version.sdk)"

ui_print "- Checking root implementation"
if [ "$BOOTMODE" ] && [ "$KSU" ]; then
    ui_print "- Installing from KernelSU app"
    ui_print "   KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
    if [ "$(which magisk)" ]; then
        ui_print "   Multiple root implementation is NOT supported"
        abort    "   Aborting!"
    fi
elif [ "$BOOTMODE" ] && [ "$APATCH" ]; then
    ui_print "- Installing from APatch app"
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
    ui_print "- Installing from Magisk app"
else
    ui_print "   Installation from recovery is NOT supported"
    ui_print "   Please install from Magisk / KernelSU / APatch app"
    abort    "   Aborting!"
fi

[ $API -ge 23 ] || abort "- Unsupported API version: $API"

ui_print "- Patching XML files"
GMS0="\"com.google.android.gms\""
STR1="allow-in-power-save package=$GMS0"
STR2="allow-in-data-usage-save package=$GMS0"
STR3="allow-unthrottled-location package=$GMS0"
STR4="allow-ignore-location-settings package=$GMS0"
NULL="/dev/null"

echo "[DEBUG] Searching system XML files..."
ui_print "- Searching default XML files"
SYS_XML="$(
SXML="$(find /system_ext/* /system/* /product/* \
/vendor/* /india/* /my_bigball/* -type f -iname '*.xml' -print 2>/dev/null)"
for S in $SXML; do
    if grep -qE "$STR1|$STR2|$STR3|$STR4" $ROOT$S 2> $NULL; then
        echo "$S"
    fi
done
)"
echo "[DEBUG] System XMLs found: $(echo "$SYS_XML" | grep -c . || echo 0)"
echo "$SYS_XML"

PATCH_SX() {
    for SX in $SYS_XML; do
        mkdir -p "$(dirname $MODPATH$SX)"
        cp -af $ROOT$SX $MODPATH$SX
        ui_print "  Patching: $SX"
        echo "[DEBUG] XML BEFORE patch: $SX"
        cat $ROOT$SX
        sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" $MODPATH/$SX
        echo "[DEBUG] XML AFTER patch: $MODPATH$SX"
        cat $MODPATH$SX
    done
}

MERGE_DIRS() {
    for P in product vendor system_ext; do
        if [ -d $MODPATH/$P ]; then
            ui_print "- Merging $P into system/"
            mkdir -p $MODPATH/system/$P
            cp -af $MODPATH/$P/. $MODPATH/system/$P/
            rm -rf $MODPATH/$P
        fi
    done
}

COPY_PRODUCT_FALLBACK() {
    if [ -d $MODPATH/system/product ]; then
        ui_print "- Copying product/ fallback for symlinked partition"
        echo "[DEBUG] Copying system/product to product/ as fallback"
        cp -af $MODPATH/system/product $MODPATH/product
        echo "[DEBUG] product/ fallback contents:"
        ls -laR $MODPATH/product
    fi
}

echo "[DEBUG] Searching conflicting module XMLs..."
MOD_XML="$(
MXML="$(find /data/adb/* -type f -iname "*.xml" -print 2>/dev/null)"
for M in $MXML; do
    if grep -qE "$STR1|$STR2|$STR3|$STR4" "$M" 2>/dev/null; then
        echo "$M"
    fi
done
)"
echo "[DEBUG] Conflicting XMLs found: $(echo "$MOD_XML" | grep -c . || echo 0)"
echo "$MOD_XML"

PATCH_MX() {
    ui_print "- Searching conflicting XML"
    for MX in $MOD_XML; do
        MOD="$(echo "$MX" | awk -F'/' '{print $5}')"
        ui_print "  $MOD: $MX"
        echo "[DEBUG] Conflicting XML BEFORE patch: $MX"
        cat "$MX"
        sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" "$MX"
        echo "[DEBUG] Conflicting XML AFTER patch: $MX"
        cat "$MX"
    done
}

PATCH_SX && PATCH_MX

# â”€â”€ Metamodule merge decision â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
HAS_METAMODULE=false
[ -L /data/adb/metamodule ] && HAS_METAMODULE=true
[ -d /data/adb/metamodule ] && HAS_METAMODULE=true
echo "[MERGE] HAS_METAMODULE=$HAS_METAMODULE"
echo "[MERGE] mountify present: $([ -d /data/adb/mountify ] && echo yes || echo no)"

if [ "$HAS_METAMODULE" = "false" ] || [ -d /data/adb/mountify ]; then
    echo "[MERGE] Running MERGE_DIRS"
    MERGE_DIRS
else
    echo "[MERGE] Skipping MERGE_DIRS (meta-overlayfs detected)"
fi

COPY_PRODUCT_FALLBACK

# â”€â”€ post-fs-data bind mount check â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
echo "[BIND] Checking post-fs-data.sh bind mount approach..."
echo "[BIND] MODDIR will be: /data/adb/modules/universal-gms-doze"
echo "[BIND] patched/ dir will contain bind-mounted XMLs"
echo "[BIND] /proc/mounts relevant entries (current):"
cat /proc/mounts | grep -E "google|sysconfig|product" | head -10

ADDON() {
    ui_print "- Inflating add-on file"
    mkdir -p $MODPATH/system/bin
    mv -f $MODPATH/gmsc $MODPATH/system/bin/gmsc
}

ui_print "- Clearing old GMS data"
cd /data/data
find . -type f -name '*gms*' -delete

FINALIZE() {
    ui_print "- Finalizing installation"

    echo "[FINAL] MODPATH full contents:"
    ls -laR $MODPATH

    echo "[FINAL] system/product contents (if exists):"
    ls -laR $MODPATH/system/product 2>/dev/null || echo "  (not present)"

    echo "[FINAL] product contents at root (if exists):"
    ls -laR $MODPATH/product 2>/dev/null || echo "  (not present)"

    echo "[FINAL] Checking google.xml in module:"
    find $MODPATH -name "google.xml" 2>/dev/null | while read F; do
        echo "  FOUND: $F"
        echo "  GMS entries remaining:"
        grep -E "com.google.android.gms" "$F" || echo "  (none â€” correctly patched)"
    done

    echo "[FINAL] SELinux contexts of module files:"
    ls -laZ $MODPATH/system/bin/gmsc 2>/dev/null
    ls -laZ $MODPATH/system/product/etc/sysconfig/google.xml 2>/dev/null
    ls -laZ $MODPATH/product/etc/sysconfig/google.xml 2>/dev/null

    ui_print "  Setting permissions"
    set_perm_recursive $MODPATH 0 0 0755 0755
    set_perm $MODPATH/system/bin/gmsc 0 2000 0755
}

ADDON && FINALIZE
echo "[DEBUG] customize.sh completed successfully"
echo "========================================"