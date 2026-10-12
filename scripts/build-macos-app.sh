#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$BASH_SOURCE")/.." && pwd)"
APP_NAME="AIStudio"
APP_BUNDLE_NAME="Supru App Builder"
if (( $# > 0 )); then OUTPUT="$1"; else OUTPUT="$ROOT/dist/$APP_BUNDLE_NAME.app"; fi
ARM_BUILD="$ROOT/.build/arm64"
INTEL_BUILD="$ROOT/.build/x86_64"
BINARY="$ROOT/.build/release/$APP_NAME"

if ! command -v swift >/dev/null 2>&1 || ! command -v lipo >/dev/null 2>&1; then
  echo "Error: Swift and lipo are required. Install Xcode Command Line Tools first." >&2
  exit 1
fi

cd "$ROOT"

echo "Building Apple Silicon (arm64) executable…"
swift build --configuration release --triple arm64-apple-macosx13.0 --scratch-path "$ARM_BUILD"

echo "Building Intel (x86_64) executable…"
swift build --configuration release --triple x86_64-apple-macosx13.0 --scratch-path "$INTEL_BUILD"

ARM_BINARY="$(find "$ARM_BUILD" -type f -path '*/release/AIStudio' -print -quit)"
INTEL_BINARY="$(find "$INTEL_BUILD" -type f -path '*/release/AIStudio' -print -quit)"

if [[ -z "$ARM_BINARY" || ! -x "$ARM_BINARY" ]]; then
  echo "Error: SwiftPM did not produce the arm64 AIStudio executable." >&2
  find "$ARM_BUILD" -maxdepth 5 -type f -name AIStudio -print >&2 || true
  exit 1
fi
if [[ -z "$INTEL_BINARY" || ! -x "$INTEL_BINARY" ]]; then
  echo "Error: SwiftPM did not produce the x86_64 AIStudio executable." >&2
  find "$INTEL_BUILD" -maxdepth 5 -type f -name AIStudio -print >&2 || true
  exit 1
fi

mkdir -p "$(dirname "$BINARY")"
lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$BINARY"
lipo "$BINARY" -verify_arch arm64 x86_64

if [[ ! -x "$BINARY" ]]; then
  echo "Error: Could not create the Universal 2 executable." >&2
  exit 1
fi

mkdir -p "$OUTPUT/Contents/MacOS" "$OUTPUT/Contents/Resources"
install -m 755 "$BINARY" "$OUTPUT/Contents/MacOS/$APP_NAME"

# Embed the existing Supru Stud app icon without altering the source image.
ICON_SOURCE="$ROOT/assets/AppIcon.icns"
if [[ -f "$ICON_SOURCE" ]]; then
  install -m 644 "$ICON_SOURCE" "$OUTPUT/Contents/Resources/AppIcon.icns"
else
  curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 \
    "https://raw.githubusercontent.com/younuspe/Stud/2b5cdb9e7fb65283c5e79b211ca17abbddf465a5/public/AppIcon.icns" \
    --output "$OUTPUT/Contents/Resources/AppIcon.icns"
fi

# Bundle the same original Supru cat image used by the README.
SUPRU_IMAGE_SOURCE="$ROOT/assets/Supru.jpg"
if [[ ! -s "$SUPRU_IMAGE_SOURCE" ]]; then
  echo "Error: assets/Supru.jpg is missing or empty." >&2
  exit 1
fi
install -m 644 "$SUPRU_IMAGE_SOURCE" "$OUTPUT/Contents/Resources/Supru.jpg"

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
    <string>com.supru.appbuilder</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Supru App Builder</string>
    <key>CFBundleDisplayName</key>
    <string>Supru App Builder</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Supru App Builder uses the microphone only when you choose voice dictation.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Supru App Builder converts your dictated prompt into editable text.</string>
</dict>
</plist>
PLIST
printf 'APPL????' > "$OUTPUT/Contents/PkgInfo"

echo "Applying local ad-hoc signature (not Apple notarization)…"
codesign --force --deep --sign - "$OUTPUT"
codesign --verify --deep --strict --verbose=2 "$OUTPUT"

echo "Created signed (not notarized) Universal 2 native macOS app bundle: $OUTPUT"
lipo "$OUTPUT/Contents/MacOS/$APP_NAME" -info
