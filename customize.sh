#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#
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
[ $API -ge 23 ] ||
abort "- Unsupported API version: $API"
ui_print "- Patching XML files"
_MODDIR="$MODPATH"
log_doze() { ui_print "$1"; }
_PARTITIONS="/system /system_ext /vendor /product /odm /oplus /oppo"
_GMS_PATTERNS="com\\.google\\.android\\.gms|com\\.google\\.android\\.gsf|allow-in-power-save|allow-in-data-usage-save|allow-unthrottled-location|allow-ignore-location-settings"
patch_xml() {
    local existing=0
    for _base in $_PARTITIONS; do
        _existing=$(find "$_MODDIR" -path "*/${_base#/}/*.xml" -type f 2>/dev/null | wc -l)
        existing=$((existing + $_existing))
    done
    if [ "$existing" -gt 0 ]; then
        log_doze "[OK] $existing sysconfig overlay(s) already present"
        return 0
    fi
    _GREP_PATTERN=""
    _SED_PATTERN=""
    for p in $_GMS_PATTERNS; do
        _GREP_PATTERN="${_GREP_PATTERN:+$_GREP_PATTERN|}$p"
        _SED_PATTERN="$_SED_PATTERN/${p/\//\\/}/d;"
    done
    local patched=0 _seen=""
    for _base in $_PARTITIONS; do
        [ -d "$_base" ] || continue
        for _dir in "$_base/etc" "$_base/oplus" "$_base/oppo"; do
            [ -d "$_dir" ] || continue
            for xml in $(find "$_dir" -type f -name "*.xml" -depth -maxdepth 2 2>/dev/null); do
                local _real
                _real=$(readlink -f "$xml" 2>/dev/null)
                [ -z "$_real" ] && _real="$xml"
                case "$_seen" in *"|$_real|"*) continue ;; esac
                _seen="${_seen}|${_real}|"

                grep -qE "$_GREP_PATTERN" "$xml" 2>/dev/null || continue

                local dest="$_MODDIR${_real}"
                mkdir -p "$(dirname "$dest")"
                if cp -af "$_real" "$dest" 2>/dev/null; then
                    sed -i "$_SED_PATTERN" "$dest"
                    log_doze "[OK] Patched: $_real"
                    patched=$((patched + 1))
                else
                    log_doze "[FAIL] Cannot copy: $_real"
                fi
            done
        done
    done
    for _sub in product vendor system_ext odm; do
        [ -d "/system/$_sub/etc/sysconfig" ] || continue
        [ -L "/system/$_sub" ] && continue
        for xml in $(find "/system/$_sub/etc/sysconfig" -type f -name "*.xml" 2>/dev/null); do
            local _real
            _real=$(readlink -f "$xml" 2>/dev/null)
            [ -z "$_real" ] && _real="$xml"
            case "$_seen" in *"|$_real|"*) continue ;; esac
            _seen="${_seen}|${_real}|"
            grep -qE "$_GREP_PATTERN" "$xml" 2>/dev/null || continue
            local dest="$_MODDIR${_real}"
            mkdir -p "$(dirname "$dest")"
            if cp -af "$_real" "$dest" 2>/dev/null; then
                sed -i "$_SED_PATTERN" "$dest"
                log_doze "[OK] Patched: $_real"
                patched=$((patched + 1))
            else
                log_doze "[FAIL] Cannot copy: $_real"
            fi
        done
    done
    _fixup_partition_layout
    if [ "$patched" -eq 0 ]; then
        log_doze "[INFO] No sysconfig XMLs with GMS entries found"
    else
        log_doze "[OK] $patched XML(s) patched ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â reboot for overlay to take effect"
    fi
}
PATCH_SX() {
    GMS0="\"com.google.android.gms\""
    STR1="allow-in-power-save package=$GMS0"
    STR2="allow-in-data-usage-save package=$GMS0"
    STR3="allow-unthrottled-location package=$GMS0"
    STR4="allow-ignore-location-settings package=$GMS0"
    NULL="/dev/null"

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
    for SX in $SYS_XML; do
        mkdir -p "$(dirname $MODPATH$SX)"
        cp -af $ROOT$SX $MODPATH$SX
        ui_print "  Patching: $SX"
        sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" $MODPATH/$SX
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
patch_xml
PATCH_SX && PATCH_MX
if [ -n "$MAGISK_VER_CODE" ] && [ -z "$KSU" ] && [ -z "$APATCH" ]; then
    MERGE_DIRS
elif [ -n "$KSU" ] && [ ! -L /data/adb/metamodule ] && [ ! -d /data/adb/metamodule ]; then
    MERGE_DIRS
fi
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
    ui_print "  Setting permissions"
    set_perm_recursive $MODPATH 0 0 0755 0755
    set_perm $MODPATH/system/bin/gmsc 0 2000 0755
}
ADDON && FINALIZE
