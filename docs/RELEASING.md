# Releasing

This checklist is for maintainers; end users only need the DMG in GitHub
Releases.

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in
   `Packaging/Info.plist`, then update `CHANGELOG.md`.
2. Run `swift test`, then compile once with complete concurrency checking and
   warnings treated as errors before running `./scripts/package_dmg.sh`.
3. Verify the packaged app with `codesign --verify --deep --strict`, verify the
   DMG with `hdiutil verify`, and confirm the executable contains `arm64` and
   `x86_64` with `lipo -archs`. Use `otool -l` to confirm both slices retain a
   macOS 13.0 minimum deployment target.
4. Create a release with concise 中文, English, and 日本語 notes. Attach the DMG
   and its SHA-256 checksum.
5. Keep every stable release available. A rebuild of an existing stable tag is
   only appropriate for a packaging correction, and must retain clear notes.
