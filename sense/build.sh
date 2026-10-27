#!/usr/bin/env bash
# 编 ParanoidSense.apk(co.aospa.sense, 自签名 priv-app)和 SenseSettingsOverlay.apk, 不用 AOSP 编译系统.
#
# 用法: build.sh <底包 system 目录> <输出目录>
# 工具(环境变量, 版本同 ../services/build.sh):
#   JAVA_HOME JDK 17;  D2J dex2jar 2.4.38;  R8 r8-8.5.35.jar;  APKTOOL apktool_2.12.1.jar(给 check_dex.py 用)
#   BT build-tools 35 目录(aapt2 zipalign apksigner);  KOTLIN_HOME kotlinc 2.0.21 目录
#
# 和上游 PixelOS fifteen 分支的区别见 ../README.md. 要点:
#   - Kotlin 标准库、AIDL stub(vendor.aospa.biometrics.face.*)、vendorImplPrebuilt.jar 都编进 APK 的 dex:
#     应用进程的 classpath 里没有 kotlin-stdlib, 也没有 services.jar
#   - 4 个 Megvii so 不压缩 + 页对齐放在 APK 里, extractNativeLibs=false, 从 APK 直接加载
set -euo pipefail

SYS=$(realpath "$1")
OUT=$(realpath -m "$2")
HERE=$(cd "$(dirname "$0")" && pwd)
: "${JAVA_HOME:=/usr/lib/jvm/java-17-openjdk-amd64}" "${D2J:?}" "${R8:?}" "${APKTOOL:?}" "${BT:?}" "${KOTLIN_HOME:?}"
UP=$HERE/../third_party/ParanoidSense
AIDL_SRC=$HERE/../services/src/vendor
KS=${KS:-$HERE/sense.keystore}
[[ -f $UP/res/raw/model_file ]] || { echo "缺上游文件, 先跑 scripts/fetch_upstream.sh" >&2; exit 1; }
if [[ ! -f $KS ]]; then
    echo "==== 生成签名密钥 $KS"
    "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KS" -storetype PKCS12 -alias sense -keyalg RSA -keysize 2048 \
        -validity 10000 -storepass android -keypass android -dname "CN=ParanoidSense GSI Port"
fi
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$OUT" "$T"/{cp,res,gen,kt,aidl,dex,lib/lib/arm64-v8a,ores}

echo "==== classpath"
"$D2J" -f -o "$T/cp/framework.jar" "$SYS/framework/framework.jar" >/dev/null
CP=$T/cp/framework.jar

echo "==== aapt2"
# 旷视模型(res/raw/model_file 等)直接用上游的
for f in $(find "$HERE/app/res" "$UP/res/raw" -type f); do "$BT/aapt2" compile "$f" -o "$T/res/"; done
"$BT/aapt2" link -o "$T/base.apk" --manifest "$HERE/app/AndroidManifest.xml" -I "$SYS/framework/framework-res.apk" \
    --java "$T/gen" --min-sdk-version 35 --target-sdk-version 35 "$T"/res/*.flat

echo "==== javac(AIDL stub) + kotlinc"
"$JAVA_HOME/bin/javac" -nowarn -encoding UTF-8 --release 17 -proc:none -cp "$CP" -d "$T/aidl" $(find "$AIDL_SRC" -name '*.java')
"$KOTLIN_HOME/bin/kotlinc" -nowarn -jvm-target 17 -classpath "$CP:$UP/lib/vendorImplPrebuilt.jar:$T/aidl" -d "$T/kt" \
    $(find "$HERE/app/src" -name '*.kt') $(find "$T/gen" -name '*.java')
"$JAVA_HOME/bin/javac" -nowarn -encoding UTF-8 --release 17 -proc:none -cp "$CP" -d "$T/kt" $(find "$T/gen" -name '*.java')
(cd "$T/kt" && "$JAVA_HOME/bin/jar" cf "$T/app.jar" .)
(cd "$T/aidl" && "$JAVA_HOME/bin/jar" cf "$T/aidl.jar" .)

echo "==== d8"
java -cp "$R8" com.android.tools.r8.D8 --release --min-api 35 --lib "$JAVA_HOME" --lib "$CP" --output "$T/dex" \
    "$T/app.jar" "$T/aidl.jar" "$UP/lib/vendorImplPrebuilt.jar" "$KOTLIN_HOME/lib/kotlin-stdlib.jar" 2>&1 \
    | grep -v -E "^Warning: (Expected stack map table|An error occurred when parsing kotlin metadata)" || true

echo "==== 组装 APK"
cp "$T/base.apk" "$T/app.apk"
(cd "$T/dex" && zip -q "$T/app.apk" classes*.dex)
cp "$UP"/lib/lib*.so "$T/lib/lib/arm64-v8a/"
(cd "$T/lib" && zip -q -0 -r "$T/app.apk" lib)
"$BT/zipalign" -f -p 4 "$T/app.apk" "$T/app-aligned.apk"
"$BT/apksigner" sign --ks "$KS" --ks-key-alias sense --ks-pass pass:android --key-pass pass:android \
    --out "$OUT/ParanoidSense.apk" "$T/app-aligned.apk"
"$BT/zipalign" -c -p 4 "$OUT/ParanoidSense.apk"
python3 -I - "$OUT/ParanoidSense.apk" <<'EOF'
import sys, zipfile
bad = [i.filename for i in zipfile.ZipFile(sys.argv[1]).infolist()
       if i.filename.endswith('.so') and i.compress_type != zipfile.ZIP_STORED]
sys.exit(f"compressed .so in APK: {bad}") if bad else print("so: stored, page-aligned")
EOF
APKTOOL="$APKTOOL" python3 -I "$HERE/../scripts/check_dex.py" --boot "$CP" "$OUT/ParanoidSense.apk"

echo "==== Settings overlay"
for f in $(find "$HERE/overlay/res" -type f); do "$BT/aapt2" compile "$f" -o "$T/ores/"; done
"$BT/aapt2" link -o "$T/overlay.apk" --manifest "$HERE/overlay/AndroidManifest.xml" \
    -I "$SYS/framework/framework-res.apk" --min-sdk-version 35 --target-sdk-version 35 "$T"/ores/*.flat
"$BT/zipalign" -f -p 4 "$T/overlay.apk" "$T/overlay-aligned.apk"
"$BT/apksigner" sign --ks "$KS" --ks-key-alias sense --ks-pass pass:android --key-pass pass:android \
    --out "$OUT/SenseSettingsOverlay.apk" "$T/overlay-aligned.apk"

(cd "$OUT" && sha256sum ParanoidSense.apk SenseSettingsOverlay.apk)
