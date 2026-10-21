#!/bin/bash
# Builds Haze and installs it in /Applications, then opens it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/build.sh" release

pkill -x Haze 2>/dev/null || true
sleep 0.5
rm -rf "/Applications/Haze.app"
/usr/bin/ditto "$ROOT/build/Haze.app" "/Applications/Haze.app"
echo "Installed /Applications/Haze.app"
open "/Applications/Haze.app"
