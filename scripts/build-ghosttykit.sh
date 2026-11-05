#!/bin/sh
# Builds GhosttyKit.xcframework from the ghostty submodule, stages it under
# Vendor/ and links it where the Xcode project expects it.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GHOSTTY="$ROOT/Vendor/ghostty"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [ ! -f "$GHOSTTY/build.zig" ]; then
  echo "ghostty submodule is empty, run: git submodule update --init" >&2
  exit 1
fi

cd "$GHOSTTY"

zig build \
  -Dapp-runtime=none \
  -Demit-xcframework=true \
  -Demit-macos-app=false \
  -Dsentry=false \
  -Di18n=false \
  -Doptimize=ReleaseFast

rm -rf "$ROOT/Vendor/GhosttyKit.xcframework"
cp -R "$GHOSTTY/macos/GhosttyKit.xcframework" "$ROOT/Vendor/"

# Xcode's linker can miss symbols in the copied universal archive until its
# symbol index is rebuilt.
xcrun ranlib "$ROOT/Vendor/GhosttyKit.xcframework/macos-arm64_x86_64/ghostty-internal.a"

ln -sfn ../Vendor/GhosttyKit.xcframework "$ROOT/macos/GhosttyKit.xcframework"

# Records what was built, so a release can refuse a stale libghostty.
"$ROOT/scripts/ghosttykit-stamp.sh" > "$ROOT/Vendor/GhosttyKit.stamp"

echo "GhosttyKit staged in $ROOT/Vendor and linked into macos/"
