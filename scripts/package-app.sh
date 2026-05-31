#!/bin/zsh
set -euo pipefail

swift build -c debug

APP_DIR=".build/debug/Easy Meeting.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp Packaging/Info.plist "$CONTENTS_DIR/Info.plist"
cp .build/debug/EasyMeeting "$MACOS_DIR/EasyMeeting"

echo "$APP_DIR"
