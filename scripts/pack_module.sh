#!/usr/bin/env bash
# 打 KSU 模块 zip.
# 用法: scripts/pack_module.sh <services/build.sh 的输出目录> <sense/build.sh 的输出目录> <输出 zip>
set -euo pipefail
SVC=$(realpath "$1"); APP=$(realpath "$2"); ZIP=$(realpath -m "$3")
HERE=$(cd "$(dirname "$0")/../module" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

cp -r "$HERE"/module.prop "$HERE"/system.prop "$HERE"/post-fs-data.sh "$HERE"/service.sh "$HERE"/system "$T/"
mkdir -p "$T/system/framework" "$T/system/priv-app/ParanoidSense" "$T/system/product/overlay"
cp "$SVC/services.jar" "$T/system/framework/"
cp "$APP/ParanoidSense.apk" "$T/system/priv-app/ParanoidSense/"
cp "$APP/SenseSettingsOverlay.apk" "$T/system/product/overlay/"

if grep -l $'\r' "$T"/*.sh "$T"/*.prop; then echo "CRLF in scripts" >&2; exit 1; fi
rm -f "$ZIP"
(cd "$T" && find . -exec touch -d '2026-10-27 00:00:00' {} + && zip -q -X -r "$ZIP" module.prop system.prop post-fs-data.sh service.sh system)
unzip -l "$ZIP"
sha256sum "$ZIP"
