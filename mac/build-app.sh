#!/usr/bin/env bash
# Builds HumanTyper.app and HumanTyper.dmg — one universal binary for Apple Silicon (M chips) and Intel Macs.
# Usage: ./build-app.sh [version]        e.g. ./build-app.sh 1.1.5
# Needs Xcode or just the Command Line Tools (xcode-select --install).
set -euo pipefail

cd "$(dirname "$0")"
VERSION="${1:-$(grep -oE '<Version>[0-9.]+' ../HumanTyper.csproj | sed 's/<Version>//')}"
OUT="${OUT:-out}"

# Build each architecture on its own and merge them with lipo. (`swift build --arch arm64 --arch x86_64`
# needs full Xcode — it fails with "xcbuild ... does not exist" on a Mac with only the Command Line Tools.)
for arch in arm64 x86_64; do swift build -c release --arch "$arch"; done
BIN="$OUT/HumanTyper-universal"
mkdir -p "$OUT"
lipo -create -output "$BIN" \
  "$(swift build -c release --arch arm64 --show-bin-path)/HumanTyper" \
  "$(swift build -c release --arch x86_64 --show-bin-path)/HumanTyper"

APP="$OUT/HumanTyper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/HumanTyper"
rm -f "$BIN"
# App icon (regenerate with: swift assets/icon/make-icon.swift, from the repo root)
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Built-in pinyin table (shared with the Windows version), used by keyboard mode to type Chinese as pinyin.
gunzip -c ../src/Resources/pinyin.dat.gz > "$APP/Contents/Resources/pinyin.dat"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>HumanTyper</string>
  <key>CFBundleDisplayName</key><string>HumanTyper</string>
  <key>CFBundleIdentifier</key><string>io.github.ydnw6.HumanTyper</string>
  <key>CFBundleExecutable</key><string>HumanTyper</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHumanReadableCopyright</key><string>Copyright (c) 2026 ydnw6, MIT License — 本软件永久免费开源，付费购买请退款并举报卖家</string>
</dict>
</plist>
PLIST

# Ad-hoc signature (no paid Apple Developer ID): required to run on Apple Silicon.
# By default an ad-hoc signature's designated requirement is the exact code hash, so macOS treats every
# new build as a different app and the Accessibility permission the user granted silently stops working
# after an update (the switch in System Settings still shows "on"). Pin the requirement to the bundle ID
# instead so the permission carries over between versions.
codesign --force --deep --sign - -r='designated => identifier "io.github.ydnw6.HumanTyper"' "$APP"
codesign --verify --verbose "$APP"

lipo -info "$APP/Contents/MacOS/HumanTyper"   # should list x86_64 arm64

# Drag-to-install disk image: HumanTyper.app + a shortcut to /Applications, in a styled window
# (background, icon positions and size from dmg/dmg-settings.py; redraw the background with
#  `swift mac/dmg/make-background.swift` from the repo root). Needs dmgbuild:  pip3 install dmgbuild
rm -f "$OUT/HumanTyper.dmg"
if command -v dmgbuild >/dev/null 2>&1; then
  dmgbuild -s dmg/dmg-settings.py -D app="$APP" "HumanTyper" "$OUT/HumanTyper.dmg"
else
  echo "dmgbuild not found (pip3 install dmgbuild): building a plain dmg without the styled window"
  STAGE="$OUT/dmg"
  rm -rf "$STAGE"; mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "HumanTyper" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$OUT/HumanTyper.dmg"
  rm -rf "$STAGE"
fi
echo "Built $APP and $OUT/HumanTyper.dmg (version $VERSION, universal arm64 + x86_64)"
