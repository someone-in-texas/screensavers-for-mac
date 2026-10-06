#!/bin/bash
# Download and install published bundles. No checkout or compiler is required.
set -euo pipefail

REPOSITORY=https://github.com/someone-in-texas/screensavers-for-mac
NAMES=('World Clock Room' 'City Drift' 'Voxel Cosmos' 'Paper Sky' 'Dapple' 'Flourish' 'Lattice' 'Strawberry Fields Forever' 'Good Research Takes Time')
IDS=(worldclockroom citydrift voxelcosmos papersky dapple flourish lattice strawberryfieldsforever goodresearchtakestime)
work=''
transaction=''
destination=''
committed=0
touched=()
had_old=()
selected=()

fail() { echo "Error: $*" >&2; exit 1; }
usage() {
    cat <<'EOF'
Usage: bash install.sh [--version VERSION] [--verify-only]

Downloads the latest published stable release, or a specific version (e.g. 0.8.1).
Installs its screen savers for the current user, replacing matching collection
bundles while preserving settings and cached maps. Requires Apple Silicon and
macOS 14.6+. No sudo, Homebrew, Git, or developer tools required.

  --version VERSION  Install this release instead of the latest (v prefix optional).
  --verify-only      Download and validate without installing anything.
  --help             Show this help.

Quit System Settings and stop any running screen saver before installing.
The optional AI helper is not installed. This does not change Gatekeeper settings
or remove quarantine attributes. Releases may be ad-hoc signed, not notarized.
EOF
}

cleanup() {
    local status=$? i name recovery_failed=0
    trap - EXIT INT TERM
    if [[ -n "$transaction" && "$committed" == 0 ]]; then
        for ((i=${#touched[@]}-1; i>=0; i--)); do
            name=${touched[$i]}
            if [[ -e "$transaction/old/$name" ]]; then
                rm -rf "$destination/$name" && mv "$transaction/old/$name" "$destination/$name" || recovery_failed=1
            elif [[ "${had_old[$i]}" == 0 && ! -e "$transaction/new/$name" ]]; then
                rm -rf "$destination/$name" || recovery_failed=1
            fi
        done
    fi
    if [[ "$recovery_failed" == 1 ]]; then
        echo "Restore failed. Previous bundles are retained at: $transaction/old" >&2
        status=1
    elif [[ -n "$transaction" ]]; then
        rm -rf "$transaction"
    fi
    [[ -z "$work" ]] || rm -rf "$work"
    exit "$status"
}

fetch() {
    curl --fail --location --show-error --silent --retry 3 \
        --connect-timeout 20 --max-time 600 --proto '=https' --proto-redir '=https' "$@"
}

check_platform() {
    [[ "$(uname -s)" == Darwin ]] || fail 'This installer requires macOS.'
    [[ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]] || fail 'Published bundles require Apple Silicon.'
    local os major minor
    os=$(/usr/bin/sw_vers -productVersion)
    major=${os%%.*}; minor=${os#*.}; minor=${minor%%.*}
    (( major > 14 || (major == 14 && minor >= 6) )) || fail 'macOS 14.6 or later is required.'
    [[ "$EUID" != 0 ]] || fail 'Run as your normal user, without sudo.'
}

verify_archive() {
    local archive=$1 manifest=$2 asset=$3 expected actual entry
    expected=$(awk -v name="$asset" '$2 == name {print $1}' "$manifest")
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || fail "Missing or ambiguous checksum for $asset."
    actual=$(shasum -a 256 "$archive"); actual=${actual%% *}
    [[ "$actual" == "$expected" ]] || fail 'Download checksum mismatch; nothing installed.'
    # Reject links and paths that could escape the extraction directory.
    zipinfo -1 "$archive" > "$work/entries"
    while IFS= read -r entry; do
        case "$entry" in
            /*|../*|*/../*|*/..|..|*\\*) fail 'Unsafe path in release ZIP.' ;;
        esac
    done < "$work/entries"
    zipinfo -l "$archive" > "$work/zip-details"
    if awk 'substr($1,1,1) == "l" {found=1} END {exit !found}' "$work/zip-details"; then
        fail 'Unexpected symbolic link in release ZIP.'
    fi
}

validate_bundles() {
    local source=$1 version=$2 i bundle plist executable identifier actual_version architecture count=0
    selected=()
    for ((i=0; i<${#NAMES[@]}; i++)); do
        bundle="$source/${NAMES[$i]}.saver"
        [[ -e "$bundle" ]] || continue
        plist="$bundle/Contents/Info.plist"
        identifier=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$plist")
        [[ "$identifier" == "com.someoneintexas.screensavers.${IDS[$i]}" ]] || fail "Unexpected bundle identifier: $bundle"
        actual_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$plist")
        [[ "$actual_version" == "$version" ]] || fail "Unexpected bundle version: $bundle"
        executable=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$plist")
        [[ -n "$executable" && "$executable" != */* && "$executable" != . && "$executable" != .. ]] || fail 'Invalid bundle executable.'
        [[ -x "$bundle/Contents/MacOS/$executable" ]] || fail "Missing executable: $bundle"
        /usr/bin/codesign --verify --strict "$bundle"
        # /usr/bin/lipo is a developer-tools shim on a clean Mac; file is standalone.
        architecture=$(/usr/bin/file -b "$bundle/Contents/MacOS/$executable")
        [[ "$architecture" == 'Mach-O 64-bit bundle arm64' || "$architecture" == *'[arm64:Mach-O 64-bit bundle arm64]'* ]] || fail "Expected an arm64 screen saver bundle: $bundle"
        selected+=("$i")
    done
    # Older releases may contain fewer savers, but never silently ignore unknown ones.
    for bundle in "$source"/*.saver; do
        [[ -e "$bundle" ]] || continue
        count=$((count+1))
    done
    (( count > 0 && count == ${#selected[@]} )) || fail 'Release contains missing or unrecognized screen savers.'
}

install_bundles() {
    local source=$1 i name target identifier
    destination=$2
    mkdir -p "$destination"
    # Check every target before changing any installed bundle.
    for i in "${selected[@]}"; do
        target="$destination/${NAMES[$i]}.saver"
        [[ ! -L "$target" ]] || fail "Refusing to replace a symbolic link: $target"
        if [[ -e "$target" ]]; then
            identifier=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$target/Contents/Info.plist")
            [[ "$identifier" == "com.someoneintexas.screensavers.${IDS[$i]}" ]] || fail "Refusing to replace unrelated bundle: $target"
        fi
    done
    transaction=$(mktemp -d "$destination/.screensavers-install.XXXXXX")
    mkdir "$transaction/new" "$transaction/old"
    for i in "${selected[@]}"; do
        name="${NAMES[$i]}.saver"
        ditto "$source/$name" "$transaction/new/$name"
        /usr/bin/codesign --verify --strict "$transaction/new/$name"
    done
    for i in "${selected[@]}"; do
        name="${NAMES[$i]}.saver"
        touched+=("$name")
        if [[ -e "$destination/$name" ]]; then
            had_old+=(1)
            mv "$destination/$name" "$transaction/old/$name"
        else
            had_old+=(0)
        fi
        mv "$transaction/new/$name" "$destination/$name"
        echo "Installed ${NAMES[$i]}"
    done
    committed=1
}

main() {
    local version='' verify_only=0 latest tag asset base
    while (( $# )); do
        case "$1" in
            --version) (( $# >= 2 )) || fail '--version needs a value.'; version=${2#v}; shift 2 ;;
            --verify-only) verify_only=1; shift ;;
            --help|-h) usage; return ;;
            *) fail "Unknown argument: $1 (use --help)." ;;
        esac
    done
    [[ -z "$version" || "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || fail 'Expected a stable version such as 0.8.1.'
    check_platform
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    work=$(mktemp -d "${TMPDIR:-/tmp}/screensavers-download.XXXXXX")
    if [[ -z "$version" ]]; then
        echo 'Finding the latest published release…'
        latest=$(fetch --output /dev/null --write-out '%{url_effective}' "$REPOSITORY/releases/latest")
        [[ "$latest" == "$REPOSITORY/releases/tag/"* ]] || fail 'Could not resolve the latest release.'
        tag=${latest##*/}; version=${tag#v}
        [[ "$tag" == v* && "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || fail 'Latest release has an unexpected version.'
    fi
    tag="v$version"
    asset="ScreensaversForMac-$tag-arm64.zip"
    base="$REPOSITORY/releases/download/$tag"
    echo "Downloading ${tag}..."
    fetch --output "$work/$asset" "$base/$asset"
    fetch --output "$work/SHA256SUMS" "$base/SHA256SUMS"
    verify_archive "$work/$asset" "$work/SHA256SUMS" "$asset"
    mkdir "$work/extracted"
    unzip -q "$work/$asset" -d "$work/extracted"
    validate_bundles "$work/extracted" "$version"
    echo "Verified ${#selected[@]} savers from $tag (checksum, bundle identities, signatures, and architecture)."
    echo 'Signature verification checks integrity; it does not establish Apple notarization.'
    if [[ "$verify_only" == 1 ]]; then
        echo 'Verification complete. Nothing installed.'
        return
    fi
    install_bundles "$work/extracted" "$HOME/Library/Screen Savers"
    echo "Installed $tag for this user. Preferences and cached maps are retained."
    echo 'Quit and reopen System Settings > Wallpaper > Screen Saver (or Screen Saver on older macOS).'
    echo 'If an older version is still running, log out and back in to reload the saver host.'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
