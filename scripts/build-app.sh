#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '%s\n' 'CallBar.app must be built on macOS with Xcode 15+.' >&2
    exit 1
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

architecture="${1:-$(uname -m)}"
case "$architecture" in
    arm64|x86_64) ;;
    *) printf 'Usage: %s [arm64|x86_64]\n' "$0" >&2; exit 2 ;;
esac

swift build --configuration release --product CallBar --arch "$architecture"
binary_directory="$(swift build --configuration release --arch "$architecture" --show-bin-path)"

app_path="$project_root/dist/$architecture/CallBar.app"
archive_path="$project_root/dist/CallBar-macOS-$architecture.zip"
mkdir -p "$app_path/Contents/MacOS"
cp "$project_root/Resources/Info.plist" "$app_path/Contents/Info.plist"
/usr/bin/install -m 755 "$binary_directory/CallBar" "$app_path/Contents/MacOS/CallBar"
/usr/bin/codesign --force --sign - --timestamp=none "$app_path"

"$project_root/scripts/verify-app.sh" "$app_path" "$architecture"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive_path"
printf 'Built: %s\n' "$archive_path"
