#!/system/bin/sh

GMS="com.google.android.gms"
GC1="auth.managed.admin.DeviceAdminReceiver"
GC2="mdm.receivers.MdmDeviceAdminReceiver"
NLL="/dev/null"

for U in $(ls /data/user 2>/dev/null); do
    for C in $GC1 $GC2; do
        pm enable --user "$U" "$GMS/$GMS.$C" > $NLL 2>&1
    done
done

dumpsys deviceidle whitelist +"$GMS" > $NLL 2>&1
cmd deviceidle sys-whitelist +"$GMS" > $NLL 2>&1

DEVICEIDLE_XML="/data/system/deviceidle.xml"
if [ -f "$DEVICEIDLE_XML" ]; then
    if grep -q "<un-wl n=\"$GMS\"" "$DEVICEIDLE_XML" 2>/dev/null; then
        sed -i "/<un-wl n=\"$GMS\"/d" "$DEVICEIDLE_XML"
        restorecon "$DEVICEIDLE_XML" 2>/dev/null
    fi
fi

cd /data/data
find . -type f -name '*gms*' -delete > $NLL 2>&1

exit 0
