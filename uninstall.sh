#!/system/bin/sh
#
# Universal GMS Doze by the
# open-source loving GL-DP and all contributors;
# Patches Google Play services app and certain processes/services to be able to use battery optimization
#

# GMS components
GMS="com.google.android.gms"
GC1="auth.managed.admin.DeviceAdminReceiver"
GC2="mdm.receivers.MdmDeviceAdminReceiver"
NLL="/dev/null"

# Re-enable collective device administrators
for U in $(ls /data/user 2>/dev/null); do
    for C in $GC1 $GC2; do
        pm enable --user $U "$GMS/$GMS.$C" > $NLL 2>&1
    done
done

# Remove GMS from battery optimization (restore to whitelist)
dumpsys deviceidle whitelist +com.google.android.gms > $NLL 2>&1

# Clear GMS cache to restore normal notification delivery
cd /data/data
find . -type f -name '*gms*' -delete > $NLL 2>&1

exit 0