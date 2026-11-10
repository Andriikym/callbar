#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '%s\n' 'App bundle verification requires macOS.' >&2
    exit 1
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_path="${1:-$project_root/dist/CallBar.app}"
info_path="$app_path/Contents/Info.plist"
executable="$app_path/Contents/MacOS/CallBar"

/usr/bin/plutil -lint "$info_path"
test -x "$executable"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info_path")" = "CallBar"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_path")" = "com.andriikym.callbar"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$info_path")" = "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$info_path")" = "13.0"
/usr/bin/lipo -verify_arch arm64 x86_64 "$executable"
/usr/bin/codesign --verify --deep --strict "$app_path"
printf '%s\n' 'Validated universal menu bar app bundle.'
