#!/bin/bash
set -euo pipefail

readonly project_dir="$(cd "$(dirname "$0")/.." && pwd)"
readonly product_name="视频一键截屏拼图"
readonly executable_name="ShotTessera"
readonly bundle_name="ShotTessera_ShotTesseraApp.bundle"
readonly output_dir="$project_dir/dist"
readonly app_path="$output_dir/$product_name.app"
readonly dmg_path="$output_dir/$product_name-0.2.0.dmg"

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
hdiutil create -volname "$product_name" -srcfolder "$app_path" -format UDZO -ov "$dmg_path"
hdiutil verify "$dmg_path"

printf 'Created %s\n' "$dmg_path"
