#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#

GMS="com.google.android.gms"
GC1="auth.managed.admin.DeviceAdminReceiver"
GC2="mdm.receivers.MdmDeviceAdminReceiver"
NLL="/dev/null"

# Re-enable GMS device admin receivers for all users
for U in $(ls /data/user 2>/dev/null); do
    for C in $GC1 $GC2; do
        pm enable --user "$U" "$GMS/$GMS.$C" > $NLL 2>&1
    done
done

# Restore GMS to the user-tier deviceidle whitelist
dumpsys deviceidle whitelist +"$GMS" > $NLL 2>&1

# Restore GMS to the system-tier whitelist (Android 12+, best-effort)
cmd deviceidle sys-whitelist +"$GMS" > $NLL 2>&1

# Remove the <un-wl> entry injected by post-fs-data.sh from deviceidle.xml
DEVICEIDLE_XML="/data/system/deviceidle.xml"
if [ -f "$DEVICEIDLE_XML" ]; then
    if grep -q "<un-wl n=\"$GMS\"" "$DEVICEIDLE_XML" 2>/dev/null; then
        sed -i "/<un-wl n=\"$GMS\"/d" "$DEVICEIDLE_XML"
        restorecon "$DEVICEIDLE_XML" 2>/dev/null
    fi
fi

# Clear GMS cache to restore normal notification delivery
cd /data/data
find . -type f -name '*gms*' -delete > $NLL 2>&1

exit 0