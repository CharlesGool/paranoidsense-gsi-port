#!/system/bin/sh
# 1. 防循环重启: 开机完成前 system_server 已经起了 3 次(正常是 1 次), 就停用本模块、存 crash 日志、重启.
# 2. 开机后补授 CAMERA(平板上没有 /system/etc/default-permissions, default-permissions xml 用不了).
MODDIR=${0%/*}
LOG=$MODDIR/mount.log

until [ "$(getprop sys.boot_completed)" = 1 ]; do
    n=$(getprop sys.system_server.start_count)
    if [ -n "$n" ] && [ "$n" -ge 3 ]; then
        echo "$(date) system_server started $n times before boot_completed: disabling module and rebooting" >>$LOG
        logcat -b crash -d > $MODDIR/crash-$(date +%Y%m%d-%H%M%S).log 2>&1
        touch $MODDIR/disable
        sync
        reboot
        exit 0
    fi
    sleep 2
done

echo "$(date) boot_completed, system_server start_count=$(getprop sys.system_server.start_count)" >>$LOG

# 等 pm 服务真的可用。boot_completed 只保证系统属性, pm 命令可能还要再过几秒才能工作。
# v2 这里 sleep 5 + pm grant 一次, 平板上失败了, 虽然后来 Settings 的运行时权限弹窗把 CAMERA 补上了。
i=0
while [ $i -lt 60 ]; do
    pm path co.aospa.sense >/dev/null 2>&1 && break
    sleep 1; i=$((i + 1))
done
echo "$(date) pm ready after ${i}s, pm path -> $(pm path co.aospa.sense 2>&1)" >>$LOG

for i in 1 2 3 4 5; do
    out=$(pm grant co.aospa.sense android.permission.CAMERA 2>&1)
    if [ -z "$out" ] || echo "$out" | grep -q "already granted"; then
        echo "ok grant CAMERA (attempt $i): ${out:-granted}" >>$LOG
        break
    fi
    echo "retry grant CAMERA (attempt $i): $out" >>$LOG
    sleep 3
done
