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
    ui_print "  KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
    if [ "$(which magisk)" ]; then
        ui_print "  Multiple root implementation is NOT supported"
        abort "  Aborting!"
    fi
elif [ "$BOOTMODE" ] && [ "$APATCH" ]; then
    ui_print "- Installing from APatch app"
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
    ui_print "- Installing from Magisk app"
else
    ui_print "  Installation from recovery is NOT supported"
    ui_print "  Please install from Magisk / KernelSU / APatch app"
    abort "  Aborting!"
fi

[ $API -ge 23 ] ||
    abort "- Unsupported API version: $API"

ui_print "- Patching XML files"

_MODDIR="$MODPATH"

log_doze() { ui_print "$1"; }

# Full partition list matching Frosty's coverage (includes OPlus/OEM extras)
_PARTITIONS="/india /my_bigball /my_carrier /my_company /my_engineering /my_heytap \
/my_manifest /my_preload /my_product /my_region /my_reserve /my_stock \
/odm /product /system /system_ext /vendor"

_GMS_PATTERNS="com\\.google\\.android\\.gms|com\\.google\\.android\\.gsf|\
allow-in-power-save|allow-in-data-usage-save|\
allow-unthrottled-location|allow-ignore-location-settings"

# Returns 0 if /$1 is a separate mount point (not folded under /system).
# Needed so _fixup_partition_layout places overlays at the right path for
# each root manager (Magisk expects $MODPATH/system/<part>/, KSU expects
# $MODPATH/<part>/ for truly separate partitions).
_is_separate_partition() {
    local p="$1"
    mountpoint -q "/$p" 2>/dev/null && return 0
    [ -L "/system/$p" ] && return 0
    grep -qE "^[^ ]+ /$p " /proc/mounts 2>/dev/null && return 0
    return 1
}

# Move overlay files to the correct location for the active root manager.
_fixup_partition_layout() {
    for _p in $_PARTITIONS; do
        p="${_p#/}"   # strip leading /
        if _is_separate_partition "$p"; then
            # Separate partition: overlay must live at $MODPATH/<part>/
            # Guard: skip if src == dst (e.g. /system on system-as-root devices)
            if [ -d "$_MODDIR/system/$p" ] && [ ! -L "$_MODDIR/system/$p" ] && \
               [ "$_MODDIR/system/$p" != "$_MODDIR/$p" ]; then
                mkdir -p "$_MODDIR/$p"
                if cp -af "$_MODDIR/system/$p/." "$_MODDIR/$p/" 2>/dev/null; then
                    rm -rf "$_MODDIR/system/$p"
                    log_doze "[OK] /$p is separate -- moved overlay to \$MODPATH/$p/"
                else
                    log_doze "[WARN] cp failed for /$p -- keeping at \$MODPATH/system/$p/"
                fi
            fi
            # KSU compatibility symlink
            if [ -d "$_MODDIR/$p" ] && [ ! -e "$_MODDIR/system/$p" ]; then
                mkdir -p "$_MODDIR/system" 2>/dev/null
                ln -sf "../$p" "$_MODDIR/system/$p" 2>/dev/null
            fi
        else
            # Integrated partition: overlay must live at $MODPATH/system/<part>/
            if [ -d "$_MODDIR/$p" ] && [ ! -L "$_MODDIR/$p" ]; then
                mkdir -p "$_MODDIR/system/$p"
                if cp -af "$_MODDIR/$p/." "$_MODDIR/system/$p/" 2>/dev/null; then
                    rm -rf "$_MODDIR/$p"
                    log_doze "[OK] /$p under /system -- moved overlay to \$MODPATH/system/$p/"
                else
                    log_doze "[WARN] cp failed for /$p -- keeping at \$MODPATH/$p/"
                fi
            fi
        fi
    done
}

patch_xml() {
    # Skip if overlays already exist from a previous run
    local existing=0
    for _base in $_PARTITIONS; do
        _existing=$(find "$_MODDIR" -path "*/${_base#/}/*.xml" -type f 2>/dev/null | wc -l)
        existing=$((existing + _existing))
    done
    if [ "$existing" -gt 0 ]; then
        log_doze "[OK] $existing sysconfig overlay(s) already present"
        return 0
    fi

    # Build grep/sed patterns from _GMS_PATTERNS
    _GREP_PATTERN=""
    _SED_PATTERN=""
    for p in $_GMS_PATTERNS; do
        _GREP_PATTERN="${_GREP_PATTERN:+$_GREP_PATTERN|}$p"
        _SED_PATTERN="$_SED_PATTERN/${p/\//\\/}/d;"
    done

    local patched=0 _seen=""

    # Primary scan: top-level partitions
    for _base in $_PARTITIONS; do
        [ -d "$_base" ] || continue
        for _dir in "$_base/etc" "$_base/oplus" "$_base/oppo"; do
            [ -d "$_dir" ] || continue
            for xml in $(find "$_dir" -type f -name "*.xml" -maxdepth 2 2>/dev/null); do
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

    # Secondary scan: legacy layouts where sub-partition is a real dir under /system
    for _sub in product vendor system_ext odm; do
        [ -d "/system/$_sub/etc/sysconfig" ] || continue
        [ -L "/system/$_sub" ] && continue   # already handled above
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
        log_doze "[OK] $patched XML(s) patched -- reboot for overlay to take effect"
    fi
}

# Patch any conflicting XMLs already installed by other modules under /data/adb/
# NOTE: STR* must be defined here, in the global scope, before MOD_XML is evaluated.
STR1="allow-in-power-save package=\"com.google.android.gms\""
STR2="allow-in-data-usage-save package=\"com.google.android.gms\""
STR3="allow-unthrottled-location package=\"com.google.android.gms\""
STR4="allow-ignore-location-settings package=\"com.google.android.gms\""
NLL="/dev/null"

PATCH_MX() {
    ui_print "- Searching conflicting XML in /data/adb"
    MOD_XML="$(
        MXML="$(find /data/adb/* -not -path "*/modules_update/*" -type f -iname "*.xml" -print 2>/dev/null)"
        for M in $MXML; do
            if grep -qE "$STR1|$STR2|$STR3|$STR4" "$M" 2>/dev/null; then
                echo "$M"
            fi
        done
    )"
    for MX in $MOD_XML; do
        MOD="$(echo "$MX" | awk -F'/' '{print $5}')"
        ui_print "  $MOD: $MX"
        sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" "$MX"
    done
}

patch_xml
PATCH_MX

ADDON() {
    ui_print "- Inflating add-on file"
    mkdir -p "$MODPATH/system/bin"
    mv -f "$MODPATH/gmsc" "$MODPATH/system/bin/gmsc"
}

ui_print "- Clearing old GMS data"
cd /data/data
find . -type f -name '*gms*' -delete 2>/dev/null

FINALIZE() {
    ui_print "- Finalizing installation"
    ui_print "  Setting permissions"
    set_perm_recursive "$MODPATH" 0 0 0755 0755
    set_perm "$MODPATH/system/bin/gmsc" 0 2000 0755
}

ADDON && FINALIZE