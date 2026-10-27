#!/usr/bin/env bash
# 从 tangorpro 底包的 services.jar 生成带 ParanoidSense 框架部分的 services.jar.
#
# 用法: build.sh <底包 system 目录(挂载的 Mystic raw 镜像里的 system/)> <输出目录>
# 需要的工具(版本是 2026-10-27 实际用的, 用环境变量指定位置):
#   JAVA_HOME  JDK 17                       (apt install openjdk-17-jdk-headless)
#   D2J        dex2jar 2.4.38 的 d2j-dex2jar.sh (github.com/ThexXTURBOXx/dex2jar)
#   R8         r8-8.5.35.jar(含 d8)         (dl.google.com/android/maven2/com/android/tools/r8/8.5.35/)
#   APKTOOL    apktool_2.12.1.jar(含 smali) (github.com/iBotPeaches/Apktool)
#   BT         build-tools 35 目录(aidl, zipalign) (dl.google.com/android/repository/build-tools_r35_linux.zip)
#
# 做的事:
#   1. 把底包的 framework.jar / services.jar / ART apex 里的 core-libart.jar 转成 class jar, 当编译 classpath
#   2. javac 编译 src/(KLC 补丁里新增的 15 个类按 Pixel 这一版 services 适配后的源码 + 3 个新的小类 + AIDL 生成的 Java)
#   3. d8 成一个 dex, 作为 services.jar 里的 classes4.dex
#   4. apktool 反编译 services.jar, 跑 apply_hooks.py(3 处 Sense 入口 + 57 处 USE_BIOMETRIC_INTERNAL 放行), 只取重新汇编的 classes.dex
#   5. 原 jar 的其他条目原样保留(classes2/3.dex 和资源不动), zipalign
# 注意: 只是框架部分。没有 ParanoidSense 应用(co.aospa.sense)时, 打开 ro.face.sense_service 也用不了人脸解锁。
set -euo pipefail

SYS=$(realpath "$1")
OUT=$(realpath -m "$2")
HERE=$(cd "$(dirname "$0")" && pwd)
: "${JAVA_HOME:=/usr/lib/jvm/java-17-openjdk-amd64}" "${D2J:?}" "${R8:?}" "${APKTOOL:?}" "${BT:?}"
T=$(mktemp -d); trap 'mountpoint -q "$T/apex" && sudo umount "$T/apex"; rm -rf "$T"' EXIT
mkdir -p "$OUT" "$T/cp" "$T/classes" "$T/dex" "$T/apex"

echo "==== classpath"
"$D2J" -f -o "$T/cp/framework.jar" "$SYS/framework/framework.jar" >/dev/null
"$D2J" -f -o "$T/cp/services.jar" "$SYS/framework/services.jar" >/dev/null
(cd "$T" && unzip -q -o "$SYS/apex/com.google.android.art.apex" original_apex && unzip -q -o original_apex apex_payload.img)
sudo mount -o loop,ro "$T/apex_payload.img" "$T/apex"
"$D2J" -f -o "$T/cp/core-libart.jar" "$T/apex/javalib/core-libart.jar" >/dev/null
sudo umount "$T/apex"

echo "==== javac + d8"
"$JAVA_HOME/bin/javac" -nowarn -encoding UTF-8 --release 17 -proc:none -d "$T/classes" \
    -cp "$T/cp/framework.jar:$T/cp/services.jar:$T/cp/core-libart.jar" $(find "$HERE/src" -name '*.java')
(cd "$T/classes" && "$JAVA_HOME/bin/jar" cf "$T/sense.jar" .)
# 必须 desugar: javac 17 对 private 方法的方法引用/内部类访问外部 private 成员, 不 desugar 会留下
# invoke-custom(invoke-instance@private) 和跨类 invoke-virtual private, ART 报 IncompatibleClassChangeError(v1 上机崩溃)
java -cp "$R8" com.android.tools.r8.D8 --release --min-api 35 \
    --lib "$JAVA_HOME" --lib "$T/cp/core-libart.jar" --lib "$T/cp/framework.jar" --classpath "$T/cp/services.jar" \
    --output "$T/dex" "$T/sense.jar"
APKTOOL="$APKTOOL" python3 -I "$HERE/../scripts/check_dex.py" "$T/dex/classes.dex"

echo "==== smali 入口补丁"
java -jar "$APKTOOL" d -f -r -o "$T/svc" "$SYS/framework/services.jar" >/dev/null
python3 -I "$HERE/apply_hooks.py" "$T/svc"
java -jar "$APKTOOL" b -f "$T/svc" -o "$T/svc_rebuilt.jar" >/dev/null

echo "==== 组装 services.jar"
python3 -I - "$SYS/framework/services.jar" "$T/svc_rebuilt.jar" "$T/dex/classes.dex" "$T/services.jar" <<'EOF'
import sys, zipfile
orig, rebuilt, sense, out = sys.argv[1:]
src = zipfile.ZipFile(orig)
new_cls = zipfile.ZipFile(rebuilt).read('classes.dex')
sense = open(sense, 'rb').read()
with zipfile.ZipFile(out, 'w') as z:
    for info in src.infolist():
        data = new_cls if info.filename == 'classes.dex' else src.read(info)
        zi = zipfile.ZipInfo(info.filename, date_time=info.date_time)
        zi.compress_type = info.compress_type; zi.external_attr = info.external_attr
        z.writestr(zi, data)
        if info.filename == 'classes3.dex':
            z4 = zipfile.ZipInfo('classes4.dex', date_time=info.date_time)
            z4.compress_type = info.compress_type; z4.external_attr = info.external_attr
            z.writestr(z4, sense)
EOF
"$BT/zipalign" -f -p 4 "$T/services.jar" "$OUT/services.jar"
cp "$T/dex/classes.dex" "$OUT/sense-classes4.dex"
(cd "$OUT" && sha256sum services.jar sense-classes4.dex)
