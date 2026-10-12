#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)"
APP_NAME="AIStudio"
if (( $# > 0 )); then OUTPUT="$1"; else OUTPUT="$ROOT/dist/$APP_NAME.app"; fi
BINARY="$ROOT/.build/release/$APP_NAME"

if ! command -v swift >/dev/null 2>&1; then
  echo "Error: Swift is required. Install Xcode Command Line Tools first." >&2
  exit 1
fi

cd "$ROOT"
swift build --configuration release

if [[ ! -x "$BINARY" ]]; then
  echo "Error: SwiftPM did not produce the expected executable at $BINARY" >&2
  exit 1
fi

mkdir -p "$OUTPUT/Contents/MacOS" "$OUTPUT/Contents/Resources"
install -m 755 "$BINARY" "$OUTPUT/Contents/MacOS/$APP_NAME"
cat > "$OUTPUT/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>AIStudio</string>
    <key>CFBundleIdentifier</key>
    <string>com.aistudio.desktop</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AIStudio</string>
    <key>CFBundleDisplayName</key>
    <string>AIStudio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Created native macOS app bundle: $OUTPUT"
echo "This build uses SwiftUI and does not start Next.js or a local web server."
