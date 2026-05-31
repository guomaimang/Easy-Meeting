#!/bin/zsh
set -euo pipefail

# Easy Meeting 分发打包：release 构建 + 内置 Node + Ad-hoc 签名 + 产出 zip。
# 产物自包含，可拷到任意 Apple Silicon Mac 运行，目标机器无需预装 Node。
# 开发调试请改用 scripts/package-app.sh。

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_DIR=".build/release/Easy Meeting.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
HELPERS_DIR="$CONTENTS_DIR/Helpers"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
AZURE_HELPER_SRC="Helpers/AzureSpeechHelper"
AZURE_HELPER_DST="$RESOURCES_DIR/AzureSpeechHelper"
ZIP_PATH=".build/release/Easy Meeting.zip"

# 1. 构建主程序与火山 Go helper（release，瘦身）
echo "==> 构建主程序 (release)"
swift build -c release
echo "==> 构建火山 Go helper (release)"
go build -C Helpers/VolcengineASTHelper -ldflags "-s -w" -o "$ROOT/.build/release/easy-meeting-ast-helper"

# 2. 定位系统 Node，确认架构为 arm64
NODE_BIN="$(command -v node || true)"
if [ -z "$NODE_BIN" ]; then
  echo "错误：未找到 node，无法内置。请先安装 Node.js。" >&2
  exit 1
fi
NODE_REAL="$(readlink -f "$NODE_BIN" 2>/dev/null || echo "$NODE_BIN")"
if ! file "$NODE_REAL" | grep -q "arm64"; then
  echo "错误：node 不是 arm64 架构（$NODE_REAL），与目标分发架构不符。" >&2
  exit 1
fi

# 3. 组装 .app 骨架
echo "==> 组装 app 包"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$HELPERS_DIR" "$RESOURCES_DIR"
cp Packaging/Info.plist "$CONTENTS_DIR/Info.plist"
cp .build/release/EasyMeeting "$MACOS_DIR/EasyMeeting"
cp .build/release/easy-meeting-ast-helper "$HELPERS_DIR/easy-meeting-ast-helper"

# 4. 内置 Node 二进制
cp "$NODE_REAL" "$HELPERS_DIR/node"
chmod +x "$HELPERS_DIR/node"

# 5. Azure helper：放 Contents/Resources/（纯资源位置，codesign 不递归当代码）。
#    确保依赖就位，复制脚本与 node_modules。
if [ ! -d "$AZURE_HELPER_SRC/node_modules" ]; then
  (cd "$AZURE_HELPER_SRC" && npm install --omit=dev)
fi
mkdir -p "$AZURE_HELPER_DST"
cp "$AZURE_HELPER_SRC/index.js" "$AZURE_HELPER_DST/index.js"
cp "$AZURE_HELPER_SRC/azureTranslation.js" "$AZURE_HELPER_DST/azureTranslation.js"
cp "$AZURE_HELPER_SRC/package.json" "$AZURE_HELPER_DST/package.json"
cp -R "$AZURE_HELPER_SRC/node_modules" "$AZURE_HELPER_DST/node_modules"

# 6. Ad-hoc 签名：先内层后外层，否则外层签名失效。
# 不用 --deep：内层 Mach-O 已逐个显式签名，node_modules 全是 JS/.d.ts 资源，
# 由外层签名作为资源封入。--deep 会误把资源当代码处理而报错。
echo "==> Ad-hoc 签名"
codesign --force -s - "$HELPERS_DIR/node"
codesign --force -s - "$HELPERS_DIR/easy-meeting-ast-helper"
codesign --force -s - "$MACOS_DIR/EasyMeeting"
codesign --force -s - "$APP_DIR"
codesign --verify --verbose "$APP_DIR"

# 7. 打 zip 便于传输
echo "==> 打包 zip"
rm -f "$ZIP_PATH"
(cd ".build/release" && /usr/bin/ditto -c -k --keepParent "Easy Meeting.app" "Easy Meeting.zip")

echo ""
echo "完成："
echo "  $APP_DIR"
echo "  $ZIP_PATH"
echo ""
echo "接收方首次打开（Apple Silicon Mac）："
echo "  解压后拖入 /Applications，再执行去隔离："
echo '  xattr -dr com.apple.quarantine "/Applications/Easy Meeting.app"'
