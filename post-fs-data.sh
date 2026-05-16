#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#

{
    GMS_PKG="com.google.android.gms"
    GMS0="\"$GMS_PKG\""
    STR1="allow-unthrottled-location package=$GMS0"
    STR2="allow-ignore-location-settings package=$GMS0"
    STR3="allow-in-power-save package=$GMS0"
    STR4="allow-in-data-usage-save package=$GMS0"
    NULL="/dev/null"
}

# --- Sysconfig XML cleanup ---
# Remove GMS whitelist entries from any sysconfig XML under /data/adb (other modules).
{
    find /data/adb/* -type f -iname "*.xml" -print 2>/dev/null |
    while IFS= read -r XML; do
        if grep -qE "$STR1|$STR2|$STR3|$STR4" "$XML" 2>/dev/null; then
            sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" "$XML"
        fi
    done
}

# --- deviceidle.xml persistent whitelist cleanup ---
# Android persists the deviceidle whitelist in /data/system/deviceidle.xml.
# If GMS was previously whitelisted, a <wl> entry may survive reboots even after
# the sysconfig overlays are patched. We inject an <un-wl> entry to permanently
# opt GMS out, and remove any conflicting <wl> entry.
DEVICEIDLE_XML="/data/system/deviceidle.xml"
if [ -f "$DEVICEIDLE_XML" ]; then
    # Remove stale <wl> (explicit whitelist) for GMS if present
    if grep -q "<wl n=\"$GMS_PKG\"" "$DEVICEIDLE_XML" 2>/dev/null; then
        sed -i "/<wl n=\"$GMS_PKG\"/d" "$DEVICEIDLE_XML"
        restorecon "$DEVICEIDLE_XML" 2>/dev/null
    fi
    # Inject <un-wl> (explicit un-whitelist) if not already present
    if ! grep -q "<un-wl n=\"$GMS_PKG\"" "$DEVICEIDLE_XML" 2>/dev/null; then
        sed -i "s|</config>|  <un-wl n=\"$GMS_PKG\" />\n</config>|" "$DEVICEIDLE_XML"
        restorecon "$DEVICEIDLE_XML" 2>/dev/null
    fi
fi