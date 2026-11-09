#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="build/MenuShelf.app"
destination="$HOME/Applications/MenuShelf.app"
[[ -x "$app/Contents/MacOS/MenuShelf" ]] || { echo 'Build MenuShelf first.' >&2; exit 1; }
codesign --verify --deep --strict "$app"
# Stop only MenuShelf, and wait for Launch Services to observe the exit.
if pgrep -x MenuShelf >/dev/null; then
  pkill -x MenuShelf
  for _ in {1..30}; do
    if ! pgrep -x MenuShelf >/dev/null; then break; fi
    sleep 0.1
  done
  if pgrep -x MenuShelf >/dev/null; then
    echo 'MenuShelf is still running. Quit it, then run this script again.' >&2
    exit 1
  fi
fi
mkdir -p "$HOME/Applications"
ditto "$app" "$destination"
codesign --verify --deep --strict "$destination"
open "$destination"
echo "Installed $destination"
