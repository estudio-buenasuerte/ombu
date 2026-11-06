#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Check version and repository"
if [[ $# -ne 1 || ! ${1:-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: usage: scripts/release.sh MAJOR.MINOR.PATCH (for example, 0.1.0)." >&2
    exit 1
fi
version="$1"
# Enso's own v-tags live in this repo, so Ombú releases carry their own prefix.
tag="ombu-$version"
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: working tree is dirty; commit or stash changes before releasing." >&2
    exit 1
fi
if [[ "$(git branch --show-current)" != main ]]; then
    echo "Error: switch to main before releasing." >&2
    exit 1
fi
if git show-ref --verify --quiet "refs/tags/$tag"; then
    echo "Error: tag $tag already exists locally; choose an unreleased version." >&2
    exit 1
fi
if git ls-remote --exit-code --tags origin "refs/tags/$tag" > /dev/null; then
    echo "Error: tag $tag already exists on origin; choose an unreleased version." >&2
    exit 1
else
    remote_status=$?
    if [[ $remote_status -ne 2 ]]; then
        echo "Error: cannot check tags on origin; restore repository access and retry." >&2
        exit 1
    fi
fi

echo "==> Check release credentials"
if ! xcrun --find notarytool > /dev/null 2>&1; then
    echo "Error: notarytool is missing; install Xcode and select it with xcode-select." >&2
    exit 1
fi
if ! xcrun notarytool history --keychain-profile ombu-notary > /dev/null 2>&1; then
    echo "Error: configure the ombu-notary profile with xcrun notarytool store-credentials ombu-notary and verify access." >&2
    exit 1
fi
if ! gh auth status > /dev/null 2>&1; then
    echo "Error: authenticate GitHub CLI with gh auth login before releasing." >&2
    exit 1
fi

echo "==> Check GhosttyKit"
expected_stamp="$("$ROOT/scripts/ghosttykit-stamp.sh")"
if [[ ! -d "$ROOT/macos/GhosttyKit.xcframework" ||
    ! -f "$ROOT/Vendor/GhosttyKit.stamp" ]] ||
    [[ "$(cat "$ROOT/Vendor/GhosttyKit.stamp")" != "$expected_stamp" ]]; then
    "$ROOT/scripts/build-ghosttykit.sh"
fi

echo "==> Archive and export Developer ID application"
mkdir -p "$ROOT/build/release"
build_log="$ROOT/build/release-$version.log"
archive="$ROOT/build/release/Ombu-$version.xcarchive"
export_dir="$ROOT/build/release/export-$version"
app="$export_dir/Ombu.app"
zip="$ROOT/build/release/Ombú-$version.zip"
build_number="$(git rev-list --count HEAD)"
rm -rf "$archive" "$export_dir"
# The Developer ID certificate is cloud managed: its private key never reaches
# this Mac, so only Xcode's export can sign with it. -allowProvisioningUpdates
# lets Xcode fetch or renew the certificate, which needs it signed in to the team.
if ! xcodebuild archive -project "$ROOT/macos/Enso.xcodeproj" -scheme Enso \
    -configuration Release -derivedDataPath "$ROOT/build/Release-DerivedData" \
    -archivePath "$archive" \
    "MARKETING_VERSION=$version" "CURRENT_PROJECT_VERSION=$build_number" \
    > "$build_log" 2>&1 ||
    ! xcodebuild -exportArchive -archivePath "$archive" \
    -exportOptionsPlist "$ROOT/scripts/export-options.plist" \
    -exportPath "$export_dir" -allowProvisioningUpdates \
    >> "$build_log" 2>&1; then
    tail -n 40 "$build_log" >&2
    echo "Error: release build failed; see $build_log." >&2
    exit 1
fi

echo "==> Verify application signature"
codesign --verify --deep --strict --verbose=2 "$app"
signature="$(codesign -dvv "$app" 2>&1)"
if ! grep -q '^Authority=Developer ID Application:' <<< "$signature"; then
    echo "Error: application is not signed with Developer ID Application; check the signing identity." >&2
    exit 1
fi

echo "==> Package application"
ditto -c -k --keepParent --sequesterRsrc "$app" "$zip"

echo "==> Notarize application"
# Structured output keeps acceptance checks independent of progress messages.
notary_result="$ROOT/build/release/notary-$version.plist"
notary_exit=0
xcrun notarytool submit "$zip" --keychain-profile ombu-notary --wait \
    --output-format plist > "$notary_result" || notary_exit=$?
notary_status="$(plutil -extract status raw -o - "$notary_result" 2>/dev/null)" || notary_status=""
if [[ $notary_exit -ne 0 || "$notary_status" != Accepted ]]; then
    cat "$notary_result" >&2
    submission_id="$(plutil -extract id raw -o - "$notary_result" 2>/dev/null)" || submission_id=""
    if [[ -n "$submission_id" ]]; then
        xcrun notarytool log "$submission_id" --keychain-profile ombu-notary >&2 || true
    fi
    echo "Error: notarization was not Accepted; resolve the submission errors before releasing." >&2
    exit 1
fi

echo "==> Staple ticket and verify Gatekeeper acceptance"
xcrun stapler staple "$app"
# The download must contain the ticket, so package again after stapling.
ditto -c -k --keepParent --sequesterRsrc "$app" "$zip"
if ! assessment="$(spctl -a -t exec -vv "$app" 2>&1)"; then
    printf '%s\n' "$assessment" >&2
    echo "Error: Gatekeeper rejected the application; resolve the assessment before releasing." >&2
    exit 1
fi
printf '%s\n' "$assessment"
if ! grep -q '^source=Notarized Developer ID$' <<< "$assessment"; then
    echo "Error: Gatekeeper did not report source=Notarized Developer ID; check the notarization ticket." >&2
    exit 1
fi

echo "==> Print archive SHA-256"
shasum -a 256 "$zip"

echo "==> Publish GitHub release"
git tag -a "$tag" -m "Ombú $version"
git push origin "$tag"
release_url="$(gh release create "$tag" "$zip" --title "Ombú $version" --generate-notes)"
printf '%s\n' "$release_url"
