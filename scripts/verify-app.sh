#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '%s\n' 'App bundle verification requires macOS.' >&2
    exit 1
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
architecture="${2:-$(uname -m)}"
case "$architecture" in
    arm64|x86_64) ;;
    *) printf 'Usage: %s [app-path] [arm64|x86_64]\n' "$0" >&2; exit 2 ;;
esac
app_path="${1:-$project_root/dist/$architecture/CallBar.app}"
info_path="$app_path/Contents/Info.plist"
executable="$app_path/Contents/MacOS/CallBar"

/usr/bin/plutil -lint "$info_path"
test -x "$executable"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info_path")" = "CallBar"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_path")" = "com.andriikym.callbar"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$info_path")" = "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$info_path")" = "13.0"
actual_architectures="$(/usr/bin/lipo -archs "$executable")"
if [[ "$actual_architectures" != "$architecture" ]]; then
    printf 'Expected %s executable, found %s.\n' "$architecture" "$actual_architectures" >&2
    exit 1
fi
/usr/bin/codesign --verify --deep --strict "$app_path"
printf 'Validated %s menu bar app bundle.\n' "$architecture"
