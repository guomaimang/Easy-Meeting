#!/bin/zsh
set -euo pipefail

swift build -c debug
go build -C Helpers/VolcengineASTHelper -o ../../.build/debug/easy-meeting-ast-helper

APP_DIR=".build/debug/Easy Meeting.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
HELPERS_DIR="$CONTENTS_DIR/Helpers"
AZURE_HELPER_SRC="Helpers/AzureSpeechHelper"
AZURE_HELPER_DST="$HELPERS_DIR/AzureSpeechHelper"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$HELPERS_DIR"
cp Packaging/Info.plist "$CONTENTS_DIR/Info.plist"
mkdir -p "$CONTENTS_DIR/Resources"
cp Packaging/AppIcon.icns "$CONTENTS_DIR/Resources/AppIcon.icns"
cp .build/debug/EasyMeeting "$MACOS_DIR/EasyMeeting"
cp .build/debug/easy-meeting-ast-helper "$HELPERS_DIR/easy-meeting-ast-helper"

# Azure 流式翻译 helper：先确保依赖就位，再复制脚本与 node_modules
if [ ! -d "$AZURE_HELPER_SRC/node_modules" ]; then
  (cd "$AZURE_HELPER_SRC" && npm install --omit=dev)
fi
mkdir -p "$AZURE_HELPER_DST"
cp "$AZURE_HELPER_SRC/index.js" "$AZURE_HELPER_DST/index.js"
cp "$AZURE_HELPER_SRC/azureTranslation.js" "$AZURE_HELPER_DST/azureTranslation.js"
cp "$AZURE_HELPER_SRC/package.json" "$AZURE_HELPER_DST/package.json"
cp -R "$AZURE_HELPER_SRC/node_modules" "$AZURE_HELPER_DST/node_modules"

echo "$APP_DIR"
