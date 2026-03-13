#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#

# Search and patch any conflicting modules (if present)
{
GMS0="\"com.google.android.gms\""
STR1="allow-unthrottled-location package=$GMS0"
STR2="allow-ignore-location-settings package=$GMS0"
STR3="allow-in-power-save package=$GMS0"
STR4="allow-in-data-usage-save package=$GMS0"
NULL="/dev/null"
}
{
find /data/adb/* -type f -iname "*.xml" -print 2>/dev/null |
while IFS= read -r XML; do
    if grep -qE "$STR1|$STR2|$STR3|$STR4" "$XML" 2>/dev/null; then
        sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" "$XML"
    fi
done
}