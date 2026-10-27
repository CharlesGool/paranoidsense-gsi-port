#!/usr/bin/env bash
# 拉 PixelOS ParanoidSense 上游(固定 commit), 构建要用里面的旷视 so、vendorImplPrebuilt.jar 和模型文件.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=https://github.com/PixelOS-AOSP/packages_apps_ParanoidSense.git
COMMIT=a500478bbb0e2933276d57796d9b410f0f8e90f8
DST=$HERE/../third_party/ParanoidSense

if [[ ! -d $DST/.git ]]; then
    git clone --filter=blob:none --no-checkout "$REPO" "$DST"
fi
git -C "$DST" fetch --depth 1 origin "$COMMIT"
git -C "$DST" -c advice.detachedHead=false checkout "$COMMIT"
ls -l "$DST/lib" "$DST/res/raw"
