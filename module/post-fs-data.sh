#!/system/bin/sh
# 平板上没有 meta-overlayfs, 自己挂载(v1.3 平板侧验证过的方式).
# services.jar 单文件 bind; 要加文件的目录: overlayfs 不接受 /data(f2fs) 做 lowerdir, 先复制到 tmpfs 再 overlay.
# 都是挂载, 重启即失效, 停用/卸载模块不用清理.
MODDIR=${0%/*}
LOG=$MODDIR/mount.log
S=/dev/faceunlock
echo "== $(date) post-fs-data" > $LOG

mkdir -p $S
mount -t tmpfs -o mode=755 tmpfs $S >>$LOG 2>&1
for d in priv-app etc/permissions etc/sysconfig product/overlay; do
    mkdir -p $S/$d
    cp -a $MODDIR/system/$d/. $S/$d/ 2>>$LOG
done
chcon -R u:object_r:system_file:s0 $S 2>>$LOG

chcon u:object_r:system_file:s0 $MODDIR/system/framework/services.jar
chmod 0644 $MODDIR/system/framework/services.jar
mount -o bind $MODDIR/system/framework/services.jar /system/framework/services.jar >>$LOG 2>&1 \
    && echo "ok bind services.jar" >>$LOG || echo "FAIL bind services.jar" >>$LOG

ov() {
    mount -t overlay overlay -o lowerdir=$S/$1:/system/$1 /system/$1 >>$LOG 2>&1 \
        && echo "ok overlay $1" >>$LOG || echo "FAIL overlay $1" >>$LOG
}
ov priv-app
ov etc/permissions
ov etc/sysconfig
ov product/overlay

for f in /system/priv-app/ParanoidSense/ParanoidSense.apk \
    /system/etc/permissions/privapp_whitelist_co.aospa.sense.xml \
    /system/etc/permissions/android.hardware.biometrics.face.xml \
    /system/etc/sysconfig/hiddenapi-whitelist-co.aospa.sense.xml \
    /system/product/overlay/SenseSettingsOverlay.apk; do
    [ -f $f ] && echo "ok $f" >>$LOG || echo "MISSING $f" >>$LOG
done
sha256sum /system/framework/services.jar >>$LOG 2>&1
