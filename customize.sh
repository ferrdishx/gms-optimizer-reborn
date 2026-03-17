#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#

# Fallback definitions in case the root manager hasn't injected these yet
# (KernelSU 3.x injects them, but guard just in case)
if ! command -v ui_print >/dev/null 2>&1; then
    ui_print() { echo "$1"; }
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

# Default MODPATH if not set by installer
[ -z "$MODPATH" ] && MODPATH="/data/adb/modules_update/universal-gms-doze"
[ -z "$API" ] && API="$(getprop ro.build.version.sdk)"

# Check root implementation
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

# Check Android API
[ $API -ge 23 ] ||
abort "- Unsupported API version: $API"

# Patch the XML and place the modified one to the original directory
ui_print "- Patching XML files"
{
GMS0="\"com.google.android.gms\""
STR1="allow-in-power-save package=$GMS0"
STR2="allow-in-data-usage-save package=$GMS0"
STR3="allow-unthrottled-location package=$GMS0"
STR4="allow-ignore-location-settings package=$GMS0"
NULL="/dev/null"
}

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

PATCH_SX() {
    for SX in $SYS_XML; do
        mkdir -p "$(dirname $MODPATH$SX)"
        cp -af $ROOT$SX $MODPATH$SX
        ui_print "  Patching: $SX"
        sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" $MODPATH/$SX
    done
}

# Always merge any loose top-level dirs into system/
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

# Search and patch any conflicting modules (if present)
MOD_XML="$(
MXML="$(find /data/adb/* -type f -iname "*.xml" -print 2>/dev/null)"
for M in $MXML; do
    if grep -qE "$STR1|$STR2|$STR3|$STR4" "$M" 2>/dev/null; then
        echo "$M"
    fi
done
)"

PATCH_MX() {
    ui_print "- Searching conflicting XML"
    for MX in $MOD_XML; do
        MOD="$(echo "$MX" | awk -F'/' '{print $5}')"
        ui_print "  $MOD: $MX"
        sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" "$MX"
    done
}

# Find and patch conflicting XML
PATCH_SX && PATCH_MX

# Merge top-level partition dirs into system/ for Magisk and KSU without metamodule
# meta-overlayfs expects product/vendor/system_ext at module root â€” skip merge if present
if [ -n "$MAGISK_VER_CODE" ] && [ -z "$KSU" ] && [ -z "$APATCH" ]; then
    MERGE_DIRS
elif [ -n "$KSU" ] && [ ! -L /data/adb/metamodule ] && [ ! -d /data/adb/metamodule ]; then
    MERGE_DIRS
fi

# Additional add-on for check gms status
ADDON() {
    ui_print "- Inflating add-on file"
    mkdir -p $MODPATH/system/bin
    mv -f $MODPATH/gmsc $MODPATH/system/bin/gmsc
}

# Clear old GMS data on first install (should fix delayed incoming messages)
ui_print "- Clearing old GMS data"
cd /data/data
find . -type f -name '*gms*' -delete

FINALIZE() {
    ui_print "- Finalizing installation"

    # Settings dir and file permission
    ui_print "  Setting permissions"
    set_perm_recursive $MODPATH 0 0 0755 0755
    set_perm $MODPATH/system/bin/gmsc 0 2000 0755
}

# Final adjustment
ADDON && FINALIZE