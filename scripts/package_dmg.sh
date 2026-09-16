#!/bin/bash
set -euo pipefail

readonly project_dir="$(cd "$(dirname "$0")/.." && pwd)"
readonly product_name="视频一键截屏拼图"
readonly volume_name="$product_name 安装器"
readonly executable_name="ShotTessera"
readonly bundle_name="ShotTessera_ShotTesseraApp.bundle"
readonly output_dir="$project_dir/dist"
readonly app_path="$output_dir/$product_name.app"
readonly dmg_path="$output_dir/$product_name-0.2.3.dmg"
readonly staging_dir="$output_dir/.dmg-staging"
readonly background_path="$output_dir/.dmg-install-background.png"
readonly writable_dmg_path="$output_dir/.dmg-writable.dmg"

mounted_device=""

cleanup() {
  if [[ -n "$mounted_device" ]]; then
    hdiutil detach "$mounted_device" -quiet || true
  fi
  rm -rf "$staging_dir" "$writable_dmg_path"
}

trap cleanup EXIT

cd "$project_dir"
swift build -c release --arch arm64 --arch x86_64

readonly binary_dir="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
# Recreate the bundle on every run. `ditto` merges into an existing directory,
# which could otherwise leave files from an earlier build in a release DMG.
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources/Licenses"

ditto "$binary_dir/$executable_name" "$app_path/Contents/MacOS/$executable_name"
readonly binary_architectures="$(lipo -archs "$app_path/Contents/MacOS/$executable_name")"
if [[ " $binary_architectures " != *" arm64 "* || " $binary_architectures " != *" x86_64 "* ]]; then
  printf 'Expected a universal arm64 + x86_64 binary.\n' >&2
  exit 1
fi
ditto "$binary_dir/$bundle_name" "$app_path/Contents/Resources/$bundle_name"
ditto "Packaging/Info.plist" "$app_path/Contents/Info.plist"
ditto "Assets/ShotTessera.icns" "$app_path/Contents/Resources/AppIcon.icns"
ditto "LICENSE" "$app_path/Contents/Resources/Licenses/MIT-LICENSE.txt"
ditto "NOTICE.md" "$app_path/Contents/Resources/Licenses/NOTICE.md"
ditto "ThirdPartyLicenses/NotoSansCJK-OFL-1.1.txt" "$app_path/Contents/Resources/Licenses/NotoSansCJK-OFL-1.1.txt"

codesign --force --sign - --timestamp=none "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

# Build a Finder installation scene rather than a bare application volume.
# The actual icons remain fully draggable; the artwork is only a visual guide.
rm -rf "$staging_dir"
mkdir -p "$staging_dir/Background"
ditto "$app_path" "$staging_dir/$product_name.app"
swift scripts/create_dmg_background.swift \
  "docs/assets/video-to-storyboard-overview.png" \
  "$background_path"
ditto "$background_path" "$staging_dir/Background/install-background.png"
ditto "Assets/ShotTessera.icns" "$staging_dir/.VolumeIcon.icns"
ln -s /Applications "$staging_dir/应用程序"

hdiutil create \
  -volname "$volume_name" \
  -srcfolder "$staging_dir" \
  -format UDRW \
  -ov \
  "$writable_dmg_path"

attach_output="$(hdiutil attach -readwrite -noverify -noautoopen "$writable_dmg_path")"
mounted_device="$(printf '%s\n' "$attach_output" | awk '/\/Volumes\// { print $1; exit }')"
# Finder may append " 1" to a volume name when an earlier image with the same
# name is mounted. Preserve the entire path from /Volumes/ onward instead of
# taking the final whitespace-delimited field.
mount_point="$(printf '%s\n' "$attach_output" | awk 'match($0, /\/Volumes\/.*/) { print substr($0, RSTART); exit }')"

if [[ -z "$mounted_device" || -z "$mount_point" ]]; then
  printf 'Unable to mount writable installer image.\n' >&2
  exit 1
fi
if [[ ! -d "$mount_point" ]]; then
  printf 'Mounted installer volume is not available at %s.\n' "$mount_point" >&2
  exit 1
fi
printf 'Styling mounted installer at %s\n' "$mount_point"

# A restrictive Finder session must never block a valid installer artifact.
# The volume still contains the application, Applications shortcut, and
# background resource; a later packaging run can write the saved view layout.
if ! osascript - "$mount_point" "$product_name.app" "应用程序" <<'APPLESCRIPT'
on run argv
  set mountPath to item 1 of argv
  set appName to item 2 of argv
  set applicationsName to item 3 of argv
  -- Resolve this before entering Finder's tell block. Otherwise Finder can
  -- interpret the local variable name as one of its own object specifiers.
  set mountedFolder to (POSIX file mountPath) as alias
  set backgroundFile to POSIX file (mountPath & "/Background/install-background.png")

  tell application "Finder"
    -- Work from the exact mounted-folder alias. Disk display names are not
    -- unique when a prior installer image is still mounted.
    open mountedFolder
    delay 1
    -- Do not address `front window`: a same-named, already-mounted DMG can be
    -- frontmost and is often read-only. The container window of this alias is
    -- the writable image that will be converted below.
    set installerWindow to container window of mountedFolder
    tell installerWindow
      set current view to icon view
      set toolbar visible to false
      set statusbar visible to false
      set bounds to {100, 100, 1380, 820}
    end tell
    -- Finder applies view changes asynchronously on recent macOS releases.
    delay 2
    tell installerWindow
      set viewOptions to icon view options of installerWindow
    end tell
    tell viewOptions
      set arrangement to not arranged
      -- Finder accepts a constrained set of icon sizes; 128 is supported by
      -- both current and older macOS releases.
      set icon size to 128
      set text size to 14
      set background picture to backgroundFile
    end tell
    delay 1
    tell installerWindow
      set position of item appName to {320, 386}
      set position of item applicationsName to {960, 386}
      close
    end tell
    open mountedFolder
  end tell
end run
APPLESCRIPT
then
  printf 'Warning: Finder did not persist the custom icon layout; created a standard installable DMG instead.\n' >&2
fi

SetFile -a V "$mount_point/Background" "$mount_point/Background/install-background.png"
SetFile -a V "$mount_point/.VolumeIcon.icns"
SetFile -a C "$mount_point"
sync
hdiutil detach "$mounted_device" -quiet
mounted_device=""
hdiutil convert "$writable_dmg_path" -format UDZO -imagekey zlib-level=9 -ov -o "$dmg_path"
hdiutil verify "$dmg_path"

printf 'Created %s\n' "$dmg_path"
