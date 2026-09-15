# ShotTessera

ShotTessera is a small, native macOS app that turns a video into one clean storyboard image. Its name joins **shot** with **tessera**, a small tile in a mosaic: selected video shots arranged into one visual whole.

It uses only Apple frameworks (`SwiftUI`, `AppKit`, `AVFoundation`, `Vision`, `CoreGraphics`, and `ImageIO`): no Electron, FFmpeg, Python runtime, analytics, network requests, or cloud upload.

## What it does

- Detects visual shot changes and selects a representative frame for each scene.
- Prefers usable shots with a visible face or person; falls back gracefully for videos without people.
- Rejects near-black, low-detail, and near-duplicate frames.
- Creates 3×3 through 8×8 rounded-card storyboard grids.
- Accepts multiple videos and processes the queue one video at a time, showing live tiles as each storyboard is assembled.
- Lets you choose MP4, MOV, M4V, AVI, MKV, WebM, 3GP/3G2, MPEG, TS/M2TS, WMV, FLV, and related common containers.
- Creates a PNG or JPEG at 1920 px wide or larger, then automatically saves it beside the source video as `video-name-shot-001.ext` (the number increments safely).
- Can overlay each selected frame's source timecode (`HH:MM:SS`) when **显示时间** is enabled.
- Keeps titles off by default; when **添加标题水印** is enabled, a custom title is placed as a large, translucent, centered overlay in the exported image.

ShotTessera is an independent project. Its name, Tessera Iris icon, and interface are original; it is not affiliated with Apple, MoviePrint, or any video service.

## App icon

The original **Tessera Iris** icon is an abstract viewfinder: nine rounded storyboard tiles form an eye, with the central pupil and gold highlight representing the selected representative frame. The app loads the 1024 px PNG at launch; a standard macOS [`.icns` package](Assets/ShotTessera.icns) and its [iconset](Assets/AppIcon.iconset) are included for future app-bundle packaging.

![ShotTessera app icon](Assets/AppIcon-1024-source.png)

## Requirements

- macOS 13 or later
- Xcode 15 or later to build and run

## Run locally

1. Clone the repository.
2. Open `Package.swift` in Xcode.
3. Choose **ShotTessera** as the scheme and press Run.
4. Choose or drop one or more common video containers into the window. The queue runs sequentially, so several videos do not compete for decoder resources. The container can be selected, but its video codec must still be decodable by your macOS installation; ShotTessera deliberately has no bundled FFmpeg runtime.

To run the algorithm tests from Terminal:

```sh
swift test
```

## Privacy

Every frame is decoded and analysed locally. ShotTessera has no account, telemetry, network client, or upload path.
See [PRIVACY.md](PRIVACY.md) for the complete statement.

## Responsible use

Only process video you own or are authorised to analyse. ShotTessera does not grant rights to copy, publish, or redistribute the source video or generated images.

## Selection approach

ShotTessera is intentionally lightweight. It rapidly samples adaptive, export-appropriate JPEG frames for scene and quality analysis, runs Apple's on-device Vision people and face detectors only on a short, representative shortlist, and reuses those selected frames for both the live grid and final sheet—avoiding a second slow random-access decode pass. It uses a strict de-duplication pass first, then fills sparse source material from distributed timestamps so a requested grid never has blank cards. It does not claim to make subjective editorial decisions about a film's best performance or story beat.

## License

[MIT](LICENSE)
