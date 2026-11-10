#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '%s\n' 'CallBar.app must be built on macOS with Xcode 15+.' >&2
    exit 1
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

binary_paths=()
for architecture in arm64 x86_64; do
    swift build --configuration release --product CallBar --arch "$architecture"
    binary_directory="$(swift build --configuration release --arch "$architecture" --show-bin-path)"
    binary_paths+=("$binary_directory/CallBar")
done

app_path="$project_root/dist/CallBar.app"
mkdir -p "$app_path/Contents/MacOS"
cp "$project_root/Resources/Info.plist" "$app_path/Contents/Info.plist"
/usr/bin/lipo -create "${binary_paths[@]}" -output "$app_path/Contents/MacOS/CallBar"
chmod 755 "$app_path/Contents/MacOS/CallBar"
/usr/bin/codesign --force --sign - --timestamp=none "$app_path"

"$project_root/scripts/verify-app.sh" "$app_path"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
    "$app_path" "$project_root/dist/CallBar-macOS-universal.zip"
printf 'Built: %s\n' "$app_path"
