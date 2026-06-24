#!/system/bin/sh

{
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

DEVICEIDLE_XML="/data/system/deviceidle.xml"
if [ -f "$DEVICEIDLE_XML" ]; then
    if grep -q "<wl n=\"$GMS_PKG\"" "$DEVICEIDLE_XML" 2>/dev/null; then
        sed -i "/<wl n=\"$GMS_PKG\"/d" "$DEVICEIDLE_XML"
        restorecon "$DEVICEIDLE_XML" 2>/dev/null
    fi
    if ! grep -q "<un-wl n=\"$GMS_PKG\"" "$DEVICEIDLE_XML" 2>/dev/null; then
        sed -i "s|</config>|  <un-wl n=\"$GMS_PKG\" />\n</config>|" "$DEVICEIDLE_XML"
        restorecon "$DEVICEIDLE_XML" 2>/dev/null
    fi
fi
