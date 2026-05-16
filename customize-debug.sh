#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#
# DEBUG VERSION - logs to /data/adb/ugd_debug.log
#

DEBUG_LOG="/data/adb/ugd_debug.log"
mkdir -p "$(dirname "$DEBUG_LOG")"
: > "$DEBUG_LOG"  # truncate on each install

dbg() { echo "[DBG][customize][$(date '+%H:%M:%S')] $1" >> "$DEBUG_LOG"; ui_print "$1"; }
dbg_raw() { echo "[DBG][customize][$(date '+%H:%M:%S')] $1" >> "$DEBUG_LOG"; }

dbg "=== Universal GMS Doze - DEBUG customize.sh ==="
dbg_raw "Date: $(date)"
dbg_raw "Kernel: $(uname -r 2>/dev/null)"
dbg_raw "Android API: $(getprop ro.build.version.sdk)"
dbg_raw "Device: $(getprop ro.product.model) / $(getprop ro.product.device)"
dbg_raw "ROM: $(getprop ro.build.display.id)"

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

dbg_raw "MODPATH: $MODPATH"
dbg_raw "BOOTMODE: $BOOTMODE"
dbg_raw "KSU: ${KSU:-<not set>}  KSU_KERNEL_VER_CODE: ${KSU_KERNEL_VER_CODE:-<not set>}  KSU_VER_CODE: ${KSU_VER_CODE:-<not set>}"
dbg_raw "APATCH: ${APATCH:-<not set>}"
dbg_raw "MAGISK_VER_CODE: ${MAGISK_VER_CODE:-<not set>}"

ui_print "- Checking root implementation"
if [ "$BOOTMODE" ] && [ "$KSU" ]; then
    ui_print "- Installing from KernelSU app"
    ui_print "  KernelSU version: $KSU_KERNEL_VER_CODE (kernel) + $KSU_VER_CODE (ksud)"
    dbg_raw "Root: KernelSU"
    if [ "$(which magisk)" ]; then
        ui_print "  Multiple root implementation is NOT supported"
        abort "  Aborting!"
    fi
elif [ "$BOOTMODE" ] && [ "$APATCH" ]; then
    ui_print "- Installing from APatch app"
    dbg_raw "Root: APatch"
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
    ui_print "- Installing from Magisk app"
    dbg_raw "Root: Magisk $MAGISK_VER_CODE"
else
    ui_print "  Installation from recovery is NOT supported"
    ui_print "  Please install from Magisk / KernelSU / APatch app"
    abort "  Aborting!"
fi

[ $API -ge 23 ] ||
    abort "- Unsupported API version: $API"

# --- Log current mount state before doing anything ---
dbg_raw "--- /proc/mounts snapshot (before patching) ---"
cat /proc/mounts >> "$DEBUG_LOG" 2>/dev/null
dbg_raw "--- end mounts ---"

dbg_raw "--- Partition existence check ---"
for _chk in /india /my_bigball /my_carrier /my_company /my_engineering /my_heytap \
             /my_manifest /my_preload /my_product /my_region /my_reserve /my_stock \
             /odm /product /system /system_ext /vendor; do
    if [ -d "$_chk" ]; then
        _mp="no"
        mountpoint -q "$_chk" 2>/dev/null && _mp="yes"
        _lnk="no"
        [ -L "/system${_chk}" ] && _lnk="yes"
        dbg_raw "  $_chk: exists=yes mountpoint=$_mp symlink_under_system=$_lnk"
    else
        dbg_raw "  $_chk: exists=no"
    fi
done
dbg_raw "--- end partition check ---"

ui_print "- Patching XML files"

_MODDIR="$MODPATH"

log_doze() { dbg "$1"; }

_PARTITIONS="/india /my_bigball /my_carrier /my_company /my_engineering /my_heytap \
/my_manifest /my_preload /my_product /my_region /my_reserve /my_stock \
/odm /product /system /system_ext /vendor"

_GMS_PATTERNS="com\\.google\\.android\\.gms|com\\.google\\.android\\.gsf|\
allow-in-power-save|allow-in-data-usage-save|\
allow-unthrottled-location|allow-ignore-location-settings"

_is_separate_partition() {
    local p="$1"
    if mountpoint -q "/$p" 2>/dev/null; then
        dbg_raw "  _is_separate_partition($p): YES (mountpoint)"
        return 0
    fi
    if [ -L "/system/$p" ]; then
        dbg_raw "  _is_separate_partition($p): YES (symlink under /system)"
        return 0
    fi
    if grep -qE "^[^ ]+ /$p " /proc/mounts 2>/dev/null; then
        dbg_raw "  _is_separate_partition($p): YES (/proc/mounts)"
        return 0
    fi
    dbg_raw "  _is_separate_partition($p): NO (integrated under /system)"
    return 1
}

_fixup_partition_layout() {
    dbg_raw "--- _fixup_partition_layout start ---"
    for _p in $_PARTITIONS; do
        p="${_p#/}"
        if _is_separate_partition "$p"; then
            if [ -d "$_MODDIR/system/$p" ] && [ ! -L "$_MODDIR/system/$p" ] && \
               [ "$_MODDIR/system/$p" != "$_MODDIR/$p" ]; then
                dbg_raw "  Moving $_MODDIR/system/$p -> $_MODDIR/$p"
                mkdir -p "$_MODDIR/$p"
                if cp -af "$_MODDIR/system/$p/." "$_MODDIR/$p/" 2>/dev/null; then
                    rm -rf "$_MODDIR/system/$p"
                    log_doze "[OK] /$p is separate -- moved overlay to \$MODPATH/$p/"
                else
                    log_doze "[WARN] cp failed for /$p -- keeping at \$MODPATH/system/$p/"
                fi
            else
                dbg_raw "  /$p separate but no $p dir under \$MODPATH/system/ -- nothing to move"
            fi
            if [ -d "$_MODDIR/$p" ] && [ ! -e "$_MODDIR/system/$p" ]; then
                mkdir -p "$_MODDIR/system" 2>/dev/null
                ln -sf "../$p" "$_MODDIR/system/$p" 2>/dev/null
                dbg_raw "  Created KSU compat symlink: $_MODDIR/system/$p -> ../$p"
            fi
        else
            if [ -d "$_MODDIR/$p" ] && [ ! -L "$_MODDIR/$p" ]; then
                dbg_raw "  Moving $_MODDIR/$p -> $_MODDIR/system/$p"
                mkdir -p "$_MODDIR/system/$p"
                if cp -af "$_MODDIR/$p/." "$_MODDIR/system/$p/" 2>/dev/null; then
                    rm -rf "$_MODDIR/$p"
                    log_doze "[OK] /$p under /system -- moved overlay to \$MODPATH/system/$p/"
                else
                    log_doze "[WARN] cp failed for /$p -- keeping at \$MODPATH/$p/"
                fi
            else
                dbg_raw "  /$p integrated, no top-level dir at \$MODPATH/$p -- nothing to move"
            fi
        fi
    done
    dbg_raw "--- _fixup_partition_layout end ---"
    dbg_raw "--- MODPATH layout after fixup ---"
    find "$_MODDIR" -maxdepth 5 -not -path '*/system/bin/*' 2>/dev/null >> "$DEBUG_LOG"
    dbg_raw "---"
}

patch_xml() {
    dbg_raw "--- patch_xml start ---"
    local existing=0
    for _base in $_PARTITIONS; do
        _existing=$(find "$_MODDIR" -path "*/${_base#/}/*.xml" -type f 2>/dev/null | wc -l)
        existing=$((existing + _existing))
    done
    dbg_raw "  Existing overlays found: $existing"
    if [ "$existing" -gt 0 ]; then
        log_doze "[OK] $existing sysconfig overlay(s) already present"
        dbg_raw "--- patch_xml end (skipped, already present) ---"
        return 0
    fi

    _GREP_PATTERN=""
    _SED_PATTERN=""
    for p in $_GMS_PATTERNS; do
        _GREP_PATTERN="${_GREP_PATTERN:+$_GREP_PATTERN|}$p"
        _SED_PATTERN="$_SED_PATTERN/${p/\//\\/}/d;"
    done
    dbg_raw "  GREP_PATTERN: $_GREP_PATTERN"
    dbg_raw "  SED_PATTERN:  $_SED_PATTERN"

    local patched=0 _seen=""

    for _base in $_PARTITIONS; do
        [ -d "$_base" ] || continue
        dbg_raw "  Scanning $_base ..."
        for _dir in "$_base/etc" "$_base/oplus" "$_base/oppo"; do
            [ -d "$_dir" ] || continue
            dbg_raw "    Entering $_dir"
            for xml in $(find "$_dir" -type f -name "*.xml" -maxdepth 2 2>/dev/null); do
                local _real
                _real=$(readlink -f "$xml" 2>/dev/null)
                [ -z "$_real" ] && _real="$xml"
                case "$_seen" in *"|$_real|"*) dbg_raw "    SKIP (seen): $_real"; continue ;; esac
                _seen="${_seen}|${_real}|"
                if grep -qE "$_GREP_PATTERN" "$xml" 2>/dev/null; then
                    dbg_raw "    MATCH: $xml (real: $_real)"
                    {
                        echo "  --- Matching lines in $_real ---"
                        grep -nE "$_GREP_PATTERN" "$xml" 2>/dev/null
                        echo "  ---"
                    } >> "$DEBUG_LOG"
                    local dest="$_MODDIR${_real}"
                    dbg_raw "    dest: $dest"
                    mkdir -p "$(dirname "$dest")"
                    if cp -af "$_real" "$dest" 2>/dev/null; then
                        dbg_raw "    cp OK -- running sed"
                        sed -i "$_SED_PATTERN" "$dest"
                        dbg_raw "    sed done -- verifying"
                        if grep -qE "$_GREP_PATTERN" "$dest" 2>/dev/null; then
                            dbg_raw "    [WARN] GMS entries still present in $dest after sed!"
                        else
                            dbg_raw "    [OK] GMS entries removed from $dest"
                        fi
                        log_doze "[OK] Patched: $_real"
                        patched=$((patched + 1))
                    else
                        log_doze "[FAIL] Cannot copy: $_real"
                        dbg_raw "    cp FAILED for $_real -> $dest"
                    fi
                else
                    dbg_raw "    no match: $xml"
                fi
            done
        done
    done

    for _sub in product vendor system_ext odm; do
        [ -d "/system/$_sub/etc/sysconfig" ] || continue
        [ -L "/system/$_sub" ] && continue
        dbg_raw "  Secondary scan: /system/$_sub/etc/sysconfig"
        for xml in $(find "/system/$_sub/etc/sysconfig" -type f -name "*.xml" 2>/dev/null); do
            local _real
            _real=$(readlink -f "$xml" 2>/dev/null)
            [ -z "$_real" ] && _real="$xml"
            case "$_seen" in *"|$_real|"*) dbg_raw "    SKIP (seen): $_real"; continue ;; esac
            _seen="${_seen}|${_real}|"
            if grep -qE "$_GREP_PATTERN" "$xml" 2>/dev/null; then
                dbg_raw "    MATCH: $xml"
                local dest="$_MODDIR${_real}"
                mkdir -p "$(dirname "$dest")"
                if cp -af "$_real" "$dest" 2>/dev/null; then
                    sed -i "$_SED_PATTERN" "$dest"
                    log_doze "[OK] Patched: $_real"
                    patched=$((patched + 1))
                else
                    log_doze "[FAIL] Cannot copy: $_real"
                fi
            fi
        done
    done

    _fixup_partition_layout

    if [ "$patched" -eq 0 ]; then
        log_doze "[INFO] No sysconfig XMLs with GMS entries found"
    else
        log_doze "[OK] $patched XML(s) patched -- reboot for overlay to take effect"
    fi
    dbg_raw "--- patch_xml end (patched=$patched) ---"
}

# Conflicting XMLs in /data/adb -- STR* defined here in global scope
STR1="allow-in-power-save package=\"com.google.android.gms\""
STR2="allow-in-data-usage-save package=\"com.google.android.gms\""
STR3="allow-unthrottled-location package=\"com.google.android.gms\""
STR4="allow-ignore-location-settings package=\"com.google.android.gms\""
NLL="/dev/null"

PATCH_MX() {
    ui_print "- Searching conflicting XML in /data/adb"
    dbg_raw "--- PATCH_MX start ---"
    MOD_XML="$(
        MXML="$(find /data/adb/* -not -path "*/modules_update/*" -type f -iname "*.xml" -print 2>/dev/null)"
        for M in $MXML; do
            if grep -qE "$STR1|$STR2|$STR3|$STR4" "$M" 2>/dev/null; then
                echo "$M"
            fi
        done
    )"
    if [ -z "$MOD_XML" ]; then
        dbg_raw "  No conflicting XMLs found in /data/adb"
    fi
    for MX in $MOD_XML; do
        MOD="$(echo "$MX" | awk -F'/' '{print $5}')"
        ui_print "  $MOD: $MX"
        dbg_raw "  Patching conflict: $MX (module: $MOD)"
        {
            echo "  --- Matching lines in $MX before patch ---"
            grep -nE "$STR1|$STR2|$STR3|$STR4" "$MX" 2>/dev/null
            echo "  ---"
        } >> "$DEBUG_LOG"
        sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" "$MX"
        dbg_raw "  After patch -- remaining GMS lines: $(grep -cE "$STR1|$STR2|$STR3|$STR4" "$MX" 2>/dev/null || echo 0)"
    done
    dbg_raw "--- PATCH_MX end ---"
}

patch_xml
PATCH_MX

ADDON() {
    ui_print "- Inflating add-on file"
    dbg_raw "Moving gmsc to system/bin/"
    mkdir -p "$MODPATH/system/bin"
    mv -f "$MODPATH/gmsc" "$MODPATH/system/bin/gmsc"
}

ui_print "- Clearing old GMS data"
dbg_raw "--- GMS data cleanup ---"
cd /data/data
GMS_FILES="$(find . -type f -name '*gms*' 2>/dev/null)"
if [ -n "$GMS_FILES" ]; then
    dbg_raw "Files to delete:"
    echo "$GMS_FILES" >> "$DEBUG_LOG"
    find . -type f -name '*gms*' -delete 2>/dev/null
    dbg_raw "Deletion done"
else
    dbg_raw "No GMS data files found"
fi
dbg_raw "--- end GMS data cleanup ---"

FINALIZE() {
    ui_print "- Finalizing installation"
    ui_print "  Setting permissions"
    set_perm_recursive "$MODPATH" 0 0 0755 0755
    set_perm "$MODPATH/system/bin/gmsc" 0 2000 0755
    dbg_raw "Permissions set"
}

ADDON && FINALIZE

dbg_raw "=== customize.sh complete ==="
dbg_raw "Debug log saved to: $DEBUG_LOG"
ui_print "- Debug log: $DEBUG_LOG"