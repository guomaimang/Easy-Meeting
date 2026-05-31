#!/bin/zsh
set -euo pipefail

swift build -c debug
go build -C Helpers/VolcengineASTHelper -o ../../.build/debug/easy-meeting-ast-helper

APP_DIR=".build/debug/Easy Meeting.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
HELPERS_DIR="$CONTENTS_DIR/Helpers"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$HELPERS_DIR"
cp Packaging/Info.plist "$CONTENTS_DIR/Info.plist"
cp .build/debug/EasyMeeting "$MACOS_DIR/EasyMeeting"
cp .build/debug/easy-meeting-ast-helper "$HELPERS_DIR/easy-meeting-ast-helper"

echo "$APP_DIR"
