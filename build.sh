#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build
output='build/航拍影院.app'
if [[ "${1:-}" == '--qa' ]]; then output='qa/航拍影院测试.app'; fi
mkdir -p "$output/Contents/MacOS" "$output/Contents/Resources"
flags=()
if [[ "${1:-}" == '--qa' ]]; then flags+=(-D QA); fi
xcrun swiftc -module-cache-path "$PWD/build/swift-cache" -swift-version 5 -target arm64-apple-macos14.0 -O -parse-as-library "${flags[@]}" Sources/Core.swift Sources/Library.swift Sources/Cinema.swift \
  -framework AppKit -framework AVFoundation -framework QuartzCore -framework IOKit \
  -o "$output/Contents/MacOS/AerialCinema"
cp Resources/Info.plist "$output/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$output/Contents/Resources/AppIcon.icns"; fi
if [[ "${1:-}" == '--qa' ]]; then
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.channel.aerialcinema.qa' "$output/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleName 航拍影院测试' "$output/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName 航拍影院测试' "$output/Contents/Info.plist"
fi
codesign --force --sign - "$output"
