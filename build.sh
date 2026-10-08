#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
destination="${1:-$project_dir/build}"
mkdir -p "$destination/Greenpad.app/Contents/MacOS" "$destination/Greenpad.app/Contents/Resources" "$destination/intermediate"
for architecture in arm64 x86_64; do
    xcrun swiftc -swift-version 5 -O -target "$architecture-apple-macos13.0" -module-cache-path "$destination/intermediate/module-cache" \
        "$project_dir"/Sources/*.swift -o "$destination/intermediate/Greenpad-$architecture" -framework AppKit -framework UniformTypeIdentifiers
done
xcrun lipo -create "$destination/intermediate/Greenpad-arm64" "$destination/intermediate/Greenpad-x86_64" -output "$destination/Greenpad.app/Contents/MacOS/Greenpad"
cp "$project_dir/Info.plist" "$destination/Greenpad.app/Contents/Info.plist"
if test -f "$project_dir/Resources/Greenpad.icns"; then cp "$project_dir/Resources/Greenpad.icns" "$destination/Greenpad.app/Contents/Resources/Greenpad.icns"; fi
/usr/bin/xattr -cr "$destination/Greenpad.app"
/usr/bin/codesign --force --sign - "$destination/Greenpad.app"
printf 'Built %s\n' "$destination/Greenpad.app"
