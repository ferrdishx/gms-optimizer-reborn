#!/system/bin/sh

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

[ -z "$MODPATH" ] && MODPATH="/data/adb/modules_update/gms-optimizer-reborn"
[ -z "$API" ] && API="$(getprop ro.build.version.sdk)"

ui_print "- Checking root implementation"
if [ "$BOOTMODE" ] && [ "$KSU" ]; then
    ui_print "- Installing from KernelSU"
    ui_print "  KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
    if [ "$(which magisk)" ]; then
        ui_print "  Multiple root implementations are NOT supported"
        abort "  Aborting!"
    fi
elif [ "$BOOTMODE" ] && [ "$APATCH" ]; then
    ui_print "- Installing from APatch"
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
    ui_print "- Installing from Magisk"
else
    ui_print "  Recovery installation is NOT supported"
    ui_print "  Install from Magisk / KernelSU / APatch"
    abort "  Aborting!"
fi

[ $API -ge 23 ] || abort "- Unsupported API: $API"

ui_print "- Patching sysconfig XML files"

_MODDIR="$MODPATH"

log_doze() { ui_print "$1"; }

_PARTITIONS="/india /my_bigball /my_carrier /my_company /my_engineering /my_heytap \
/my_manifest /my_preload /my_product /my_region /my_reserve /my_stock \
/odm /product /system /system_ext /vendor"

_GMS_PATTERNS="allow-in-power-save.*com.google.android.gms allow-in-data-usage-save.*com.google.android.gms allow-unthrottled-location.*com.google.android.gms allow-ignore-location-settings.*com.google.android.gms"

_is_separate_partition() {
    local p="$1"
    mountpoint -q "/$p" 2>/dev/null && return 0
    [ -L "/system/$p" ] && return 0
    grep -qE "^[^ ]+ /$p " /proc/mounts 2>/dev/null && return 0
    return 1
}

_fixup_partition_layout() {
    for _p in $_PARTITIONS; do
        p="${_p#/}"
        if _is_separate_partition "$p"; then
            if [ -d "$_MODDIR/system/$p" ] && [ ! -L "$_MODDIR/system/$p" ] && \
               [ "$_MODDIR/system/$p" != "$_MODDIR/$p" ]; then
                mkdir -p "$_MODDIR/$p"
                if cp -af "$_MODDIR/system/$p/." "$_MODDIR/$p/" 2>/dev/null; then
                    rm -rf "$_MODDIR/system/$p"
                    log_doze "[OK] /$p is separate -- moved to \$MODPATH/$p/"
                else
                    log_doze "[WARN] cp failed for /$p"
                fi
            fi
        else
            if [ -d "$_MODDIR/$p" ] && [ ! -L "$_MODDIR/$p" ]; then
                mkdir -p "$_MODDIR/system/$p"
                if cp -af "$_MODDIR/$p/." "$_MODDIR/system/$p/" 2>/dev/null; then
                    rm -rf "$_MODDIR/$p"
                    log_doze "[OK] /$p under /system -- moved to \$MODPATH/system/$p/"
                else
                    log_doze "[WARN] cp failed for /$p"
                fi
            fi
        fi
    done
}

patch_xml() {
    local existing=0
    for _base in $_PARTITIONS; do
        _existing=$(find "$_MODDIR" -path "*/${_base#/}/*.xml" -type f 2>/dev/null | wc -l)
        existing=$((existing + _existing))
    done
    if [ "$existing" -gt 0 ]; then
        log_doze "[OK] $existing overlay(s) already present"
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
        log_doze "[OK] $patched XML(s) patched"
    fi
}

PATCH_MX() {
    ui_print "- Checking for conflicting modules"
    GMS_PKG="com.google.android.gms"

    GMS_PATTERNS="
    allow-unthrottled-location.*$GMS_PKG
    allow-ignore-location-settings.*$GMS_PKG
    allow-in-power-save.*$GMS_PKG
    allow-in-data-usage-save.*$GMS_PKG
    "

    find /data/adb/modules* -type f -path "*/etc/sysconfig/*.xml" -print 2>/dev/null |
    while IFS= read -r XML; do
        for PAT in $GMS_PATTERNS; do
            if grep -qE "$PAT" "$XML" 2>/dev/null; then
                sed -i "/$PAT/d" "$XML"
            fi
        done
    done
}

patch_xml
PATCH_MX

ui_print "- Installing gmsc binary"
mkdir -p "$MODPATH/system/bin"
mv -f "$MODPATH/gmsc" "$MODPATH/system/bin/gmsc"

ui_print "- Clearing GMS cache"
cd /data/data
find . -type f -name '*gms*' -delete 2>/dev/null

ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0755
set_perm "$MODPATH/system/bin/gmsc" 0 2000 0755
