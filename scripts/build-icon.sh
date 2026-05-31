#!/bin/zsh
set -euo pipefail

# 从 logo 生成 macOS 应用图标 Packaging/AppIcon.icns。
# 流程：make-icon.swift 合成 1024 底图（白色圆角底板 + logo 居中）
#       → sips 生成各尺寸 → iconutil 打包 icns。
# 用法：zsh scripts/build-icon.sh [源 logo，默认 logo.png]

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC_LOGO="${1:-logo.png}"
if [ ! -f "$SRC_LOGO" ]; then
  echo "错误：找不到源 logo $SRC_LOGO" >&2
  exit 1
fi

WORK="$(mktemp -d)"
ICONSET="$WORK/AppIcon.iconset"
BASE="$WORK/icon_1024.png"
mkdir -p "$ICONSET"

# 1. 合成 1024 底图
swift scripts/make-icon.swift "$SRC_LOGO" "$BASE"

# 2. 生成 macOS 标准 iconset 尺寸矩阵
sips -z 16 16   "$BASE" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32   "$BASE" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32   "$BASE" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64   "$BASE" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128 "$BASE" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256 "$BASE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BASE" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512 "$BASE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BASE" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$BASE"                    "$ICONSET/icon_512x512@2x.png"

# 3. 打包 icns
iconutil -c icns "$ICONSET" -o Packaging/AppIcon.icns

rm -rf "$WORK"
echo "已生成 Packaging/AppIcon.icns"
