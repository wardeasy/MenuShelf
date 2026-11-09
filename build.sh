#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
identity=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign)
      [[ $# -ge 2 && -n "$2" ]] || { echo 'Missing signing identity.' >&2; exit 2; }
      identity="$2"; shift 2 ;;
    --ad-hoc) identity="-"; shift ;;
    *) echo 'Usage: ./build.sh --sign "Signing Identity" | --ad-hoc' >&2; exit 2 ;;
  esac
done
if [[ -z "$identity" ]]; then
  echo 'Choose --sign "Signing Identity" for repeatable local updates, or --ad-hoc for a development build.' >&2
  exit 2
fi
if [[ "$identity" == "-" ]]; then
  echo 'Development signing: rebuilding may require granting Accessibility permission again.' >&2
fi
app="build/MenuShelf.app"
mkdir -p "$app/Contents/MacOS" build/module-cache
cp Resources/Info.plist "$app/Contents/Info.plist"
xcrun swiftc Sources/main.swift \
  -target "$(uname -m)-apple-macos13.0" \
  -module-cache-path build/module-cache \
  -framework AppKit -framework ApplicationServices \
  -o "$app/Contents/MacOS/MenuShelf"
codesign --force --sign "$identity" "$app"
codesign --verify --deep --strict "$app"
codesign -d -r- "$app"
echo "Built $app"
