#!/bin/bash
# Packs a Haze release for GitHub.
#
#   ./release.sh 0.1.1
#
# Bumps VERSION, builds Haze and zips it to build/Haze.zip. Then commit, tag
# v<version>, push, and attach build/Haze.zip to a GitHub release for that tag
# (the README's download link always points at the latest release's Haze.zip).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION_NUMBER="${1:?usage: ./release.sh <version>}"

echo "$VERSION_NUMBER" > "$ROOT/VERSION"
"$ROOT/build.sh" release

rm -f "$ROOT/build/Haze.zip"
# ditto keeps the bundle's signature, symlinks and attributes intact.
/usr/bin/ditto -c -k --keepParent "$ROOT/build/Haze.app" "$ROOT/build/Haze.zip"
echo "Packed build/Haze.zip ($(du -h "$ROOT/build/Haze.zip" | cut -f1)) for $VERSION_NUMBER"
