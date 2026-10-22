#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

BUILD_MODE="release"
if [ "$1" == "--debug" ]; then
    BUILD_MODE="debug"
fi

echo "==> Building MacClipboard ($BUILD_MODE mode)..."
if [ "$BUILD_MODE" == "release" ]; then
    swift build -c release
    BIN_PATH=$(find "$DIR/.build" -name "MacClipboard" -path "*/Release/*" -type f -perm +111 2>/dev/null | head -n 1)
else
    swift build
    BIN_PATH=$(find "$DIR/.build" -name "MacClipboard" -path "*/Debug/*" -type f -perm +111 2>/dev/null | head -n 1)
fi

if [ -z "$BIN_PATH" ] || [ ! -f "$BIN_PATH" ]; then
    BIN_PATH=$(find "$DIR/.build" -name "MacClipboard" -type f -perm +111 2>/dev/null | head -n 1)
fi

echo "==> Using binary at: $BIN_PATH"

APP_NAME="MacClipboard.app"
APP_DIR="$DIR/$APP_NAME"
TARGET_APPS_DIR="$HOME/Applications"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/MacClipboard"
strip "$APP_DIR/Contents/MacOS/MacClipboard" 2>/dev/null || true
chmod +x "$APP_DIR/Contents/MacOS/MacClipboard"

if [ -f "$DIR/AppIcon.icns" ]; then
    cp "$DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacClipboard</string>
    <key>CFBundleIdentifier</key>
    <string>com.hayatkhan.macclipboard</string>
    <key>CFBundleName</key>
    <string>MacClipboard</string>
    <key>CFBundleDisplayName</key>
    <string>MacClipboard</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacClipboard needs permission to paste into active applications.</string>
</dict>
</plist>
EOF

echo "==> Signing application bundle..."
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

mkdir -p "$TARGET_APPS_DIR"
rm -rf "$TARGET_APPS_DIR/$APP_NAME"
cp -R "$APP_DIR" "$TARGET_APPS_DIR/"

echo "==> Successfully installed MacClipboard to $TARGET_APPS_DIR/$APP_NAME"
