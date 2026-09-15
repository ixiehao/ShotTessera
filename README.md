# 视频一键截屏拼图 · ShotTessera

[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

**视频一键截屏拼图** is the Chinese name of ShotTessera, a small native macOS app for turning video screenshots into one clean storyboard, contact sheet, or video screenshot collage. Its name joins **shot** with **tessera**, a small tile in a mosaic: selected video shots arranged into one visual whole.

It uses only Apple frameworks (`SwiftUI`, `AppKit`, `AVFoundation`, `Vision`, `CoreGraphics`, and `ImageIO`): no Electron, FFmpeg, Python runtime, analytics, network requests, or cloud upload.

## From video to contact sheet, at a glance

![ShotTessera flow: video frames become a contact sheet and then an exported image](docs/assets/video-to-storyboard-overview.png)

| 1. Add video | 2. Select useful frames | 3. Build the sheet | 4. Export locally |
| --- | --- | --- | --- |
| Drop one video or queue several. | Detect cuts; avoid black, blurry, and duplicate frames; prefer people when present. | Preview each tile as it arrives in a 3×3 to 8×8 storyboard grid. | Save a 1920 px+ PNG or JPEG next to the source video. |

## What it does

- Detects visual shot changes and selects a representative frame for each scene.
- Prefers usable shots with a visible face or person; falls back gracefully for videos without people.
- Rejects near-black, low-detail, and near-duplicate frames.
- Creates 3×3 through 8×8 rounded-card storyboard grids.
- Accepts multiple videos and processes the queue one video at a time, showing live tiles as each storyboard is assembled.
- Lets you choose MP4, MOV, M4V, AVI, MKV, WebM, 3GP/3G2, MPEG, TS/M2TS, WMV, FLV, and related common containers.
- Creates a PNG or JPEG at 1920 px wide or larger, then automatically saves it beside the source video as `video-name-shot-001.ext` (the number increments safely).
- Can overlay each selected frame's source timecode (`HH:MM:SS`) when **显示时间** is enabled.
- Keeps titles off by default; when **标题水印** is enabled, the source video's filename is placed as a large, translucent, centered overlay in the exported image using bundled **Noto Sans CJK SC Bold**.

ShotTessera is an independent project. Its name, Tessera Iris icon, and interface are original; it is not affiliated with Apple, MoviePrint, or any video service.

## Search terms

Video screenshot collage, video contact sheet, storyboard generator, movie frame extractor, macOS video screenshot tool, 视频截屏拼图, 视频一键截图, 分镜图生成器, 视频九宫格截图, 動画スクリーンショット, 動画コンタクトシート.

For a GitHub repository description, social-preview copy, and recommended topics, see [GitHub metadata](docs/GITHUB_METADATA.md).

## Rights and attribution

- The Swift source, documentation, and Tessera Iris artwork in this repository are original project material and are released under the repository's [MIT License](LICENSE).
- The app uses only Apple SDK frameworks at runtime; it does not include third-party application code, packages, analytics SDKs, network clients, or copied MoviePrint assets.
- The only bundled third-party asset is `NotoSansCJKsc-Bold.otf` (Noto Sans CJK SC Bold 2.004). It is kept unmodified and distributed under the **SIL Open Font License 1.1**, which permits embedding and commercial redistribution with its notice and license. See [NOTICE.md](NOTICE.md) and [the included OFL text](ThirdPartyLicenses/NotoSansCJK-OFL-1.1.txt).
- Source videos and any pre-existing logos, subtitles, or watermarks within them remain the user's responsibility. Generating a storyboard does not grant publication or redistribution rights.

This is a source-and-asset audit for this repository, not legal advice for a particular video or distribution scenario.

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

## Build a DMG

On an Apple Silicon Mac, run:

```sh
./scripts/package_dmg.sh
```

This creates `dist/视频一键截屏拼图-0.1.0.dmg`, containing the Chinese-named
macOS app, app icon, runtime resources, and all license notices. The package is
ad-hoc signed for local integrity but is not Apple-notarized; when sharing it,
recipients may need to Control-click the app and choose **Open** the first time.

## Privacy

Every frame is decoded and analysed locally. ShotTessera has no account, telemetry, network client, or upload path.
See [PRIVACY.md](PRIVACY.md) for the complete statement.

## Responsible use

Only process video you own or are authorised to analyse. ShotTessera does not grant rights to copy, publish, or redistribute the source video or generated images.

## Selection approach

ShotTessera is intentionally lightweight. It rapidly samples adaptive, export-appropriate JPEG frames for scene and quality analysis, runs Apple's on-device Vision people and face detectors only on a short, representative shortlist, and reuses those selected frames for both the live grid and final sheet—avoiding a second slow random-access decode pass. It uses a strict de-duplication pass first, then fills sparse source material from distributed timestamps so a requested grid never has blank cards. It does not claim to make subjective editorial decisions about a film's best performance or story beat.

## License

The project code and original assets are [MIT](LICENSE). The bundled Noto font remains under its separate [SIL Open Font License 1.1](ThirdPartyLicenses/NotoSansCJK-OFL-1.1.txt).
