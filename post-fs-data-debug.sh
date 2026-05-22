#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#
# DEBUG VERSION - appends to /data/adb/ugd_debug.log
#

DEBUG_LOG="/data/adb/ugd_debug.log"
mkdir -p "$(dirname "$DEBUG_LOG")"

dbg() { echo "[DBG][post-fs-data][$(date '+%H:%M:%S')] $1" >> "$DEBUG_LOG"; }

dbg "=== post-fs-data.sh start ==="
dbg "Date: $(date)"

{
    GMS_PKG="com.google.android.gms"

    # Regex patterns (NOW MATCH customize.sh)
    GMS_PATTERNS="
    allow-unthrottled-location.*$GMS_PKG
    allow-ignore-location-settings.*$GMS_PKG
    allow-in-power-save.*$GMS_PKG
    allow-in-data-usage-save.*$GMS_PKG
    "

    NULL="/dev/null"
}

# --- Log mount state at post-fs-data time ---
dbg "--- /proc/mounts at post-fs-data ---"
cat /proc/mounts >> "$DEBUG_LOG" 2>/dev/null
dbg "--- end mounts ---"

# --- Log current overlay files present in module dir ---
MODDIR="/data/adb/modules/universal-gms-doze"
dbg "--- Module overlay tree ($MODDIR) ---"
find "$MODDIR" -maxdepth 6 -not -path '*/system/bin/*' 2>/dev/null >> "$DEBUG_LOG"
dbg "--- end overlay tree ---"

# --- Log deviceidle whitelist BEFORE any changes ---
dbg "--- deviceidle whitelist BEFORE ---"
dumpsys deviceidle whitelist 2>/dev/null >> "$DEBUG_LOG"
dbg "--- end whitelist ---"

# --- Log deviceidle.xml state BEFORE ---
DEVICEIDLE_XML="/data/system/deviceidle.xml"
dbg "--- $DEVICEIDLE_XML BEFORE ---"
if [ -f "$DEVICEIDLE_XML" ]; then
    cat "$DEVICEIDLE_XML" >> "$DEBUG_LOG" 2>/dev/null
else
    dbg "  File does not exist yet"
fi
dbg "--- end deviceidle.xml ---"

# --- Sysconfig XML cleanup ---
dbg "--- Sysconfig XML conflict scan ---"
find /data/adb/modules* -type f -path "*/etc/sysconfig/*.xml" -print 2>/dev/null |
while IFS= read -r XML; do
    for PAT in $GMS_PATTERNS; do
        if grep -qE "$PAT" "$XML" 2>/dev/null; then
            dbg "  Conflict found: $XML"
            dbg "  Matching lines before sed:"
            grep -nE "$PAT" "$XML" 2>/dev/null >> "$DEBUG_LOG"
            sed -i "/$PAT/d" "$XML"
            REMAINING=$(grep -cE "$PAT" "$XML" 2>/dev/null || echo 0)
            dbg "  Remaining GMS lines after sed: $REMAINING"
        else
            dbg "  Clean (no conflict): $XML"
        fi
    done
done
dbg "--- end sysconfig scan ---"

# --- deviceidle.xml cleanup and un-wl injection ---
dbg "--- deviceidle.xml patch ---"
if [ -f "$DEVICEIDLE_XML" ]; then
    HAS_WL="$(grep -c "<wl n=\"$GMS_PKG\"" "$DEVICEIDLE_XML" 2>/dev/null || echo 0)"
    HAS_UNWL="$(grep -c "<un-wl n=\"$GMS_PKG\"" "$DEVICEIDLE_XML" 2>/dev/null || echo 0)"
    dbg "  <wl> entries for GMS: $HAS_WL"
    dbg "  <un-wl> entries for GMS: $HAS_UNWL"

    if [ "$HAS_WL" -gt 0 ]; then
        dbg "  Removing <wl n=\"$GMS_PKG\"> ..."
        sed -i "/<wl n=\"$GMS_PKG\"/d" "$DEVICEIDLE_XML"
        restorecon "$DEVICEIDLE_XML" 2>/dev/null
        AFTER_WL="$(grep -c "<wl n=\"$GMS_PKG\"" "$DEVICEIDLE_XML" 2>/dev/null || echo 0)"
        dbg "  <wl> entries after removal: $AFTER_WL"
    fi

    if [ "$HAS_UNWL" -eq 0 ]; then
        dbg "  Injecting <un-wl n=\"$GMS_PKG\" /> ..."
        sed -i "s|</config>|  <un-wl n=\"$GMS_PKG\" />\n</config>|" "$DEVICEIDLE_XML"
        restorecon "$DEVICEIDLE_XML" 2>/dev/null
        AFTER_UNWL="$(grep -c "<un-wl n=\"$GMS_PKG\"" "$DEVICEIDLE_XML" 2>/dev/null || echo 0)"
        dbg "  <un-wl> entries after injection: $AFTER_UNWL"
    else
        dbg "  <un-wl> already present -- skipping injection"
    fi

    dbg "--- $DEVICEIDLE_XML AFTER ---"
    cat "$DEVICEIDLE_XML" >> "$DEBUG_LOG" 2>/dev/null
    dbg "--- end deviceidle.xml after ---"
else
    dbg "  $DEVICEIDLE_XML does not exist -- skipping (first boot?)"
fi
dbg "--- end deviceidle.xml patch ---"

# --- Log SELinux context ---
dbg "--- SELinux context of deviceidle.xml ---"
ls -Z "$DEVICEIDLE_XML" 2>/dev/null >> "$DEBUG_LOG"
dbg "---"

dbg "=== post-fs-data.sh complete ==="