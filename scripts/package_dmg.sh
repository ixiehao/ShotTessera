#!/bin/bash
set -euo pipefail

readonly project_dir="$(cd "$(dirname "$0")/.." && pwd)"
readonly product_name="视频一键截屏拼图"
readonly executable_name="ShotTessera"
readonly bundle_name="ShotTessera_ShotTesseraApp.bundle"
readonly output_dir="$project_dir/dist"
readonly app_path="$output_dir/$product_name.app"
readonly dmg_path="$output_dir/$product_name-0.2.2.dmg"
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
ln -s /Applications "$staging_dir/应用程序"

hdiutil create \
  -volname "$product_name" \
  -srcfolder "$staging_dir" \
  -format UDRW \
  -ov \
  "$writable_dmg_path"

attach_output="$(hdiutil attach -readwrite -noverify -noautoopen "$writable_dmg_path")"
mounted_device="$(printf '%s\n' "$attach_output" | awk '/\/Volumes\// { print $1; exit }')"
mount_point="$(printf '%s\n' "$attach_output" | awk '/\/Volumes\// { print $NF; exit }')"

if [[ -z "$mounted_device" || -z "$mount_point" ]]; then
  printf 'Unable to mount writable installer image.\n' >&2
  exit 1
fi

osascript - "$product_name" "$product_name.app" "应用程序" <<'APPLESCRIPT'
on run argv
  set volumeName to item 1 of argv
  set appName to item 2 of argv
  set applicationsName to item 3 of argv

  tell application "Finder"
    tell disk volumeName
      open
      tell container window
        set current view to icon view
        set toolbar visible to false
        set statusbar visible to false
        set bounds to {100, 100, 1380, 820}
      end tell
      set viewOptions to the icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 144
      set text size of viewOptions to 14
      set backgroundImage to file "install-background.png" of folder "Background"
      set background picture of viewOptions to backgroundImage
      set position of item appName to {320, 386}
      set position of item applicationsName to {960, 386}
      close
      open
      update without registering applications
    end tell
  end tell
end run
APPLESCRIPT

SetFile -a V "$mount_point/Background" "$mount_point/Background/install-background.png"
sync
hdiutil detach "$mounted_device" -quiet
mounted_device=""
hdiutil convert "$writable_dmg_path" -format UDZO -imagekey zlib-level=9 -ov -o "$dmg_path"
hdiutil verify "$dmg_path"

printf 'Created %s\n' "$dmg_path"
