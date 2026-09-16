# 视频一键截屏拼图 · ShotTessera

[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md)

**ShotTessera** is a small native macOS app that turns video into a clean contact sheet, storyboard, or screenshot collage. It is also named **视频一键截屏拼图**.

> **Stable release:** [v0.2.2 universal DMG](https://github.com/ixiehao/ShotTessera/releases/tag/v0.2.2) · macOS 13+ · Apple Silicon and Intel

## Download

1. Open [the latest release](https://github.com/ixiehao/ShotTessera/releases/latest) and download the universal **DMG**.
2. Open it and drag **视频一键截屏拼图** into **Applications**.
3. Open the app and choose or drop in one or more videos.

Requires an Apple Silicon or Intel Mac running macOS 13 or later. The app is ad-hoc signed but not Apple-notarized; if macOS shows a Gatekeeper warning on first launch, Control-click the app and choose **Open**.

## Project

- Developer: [xao](https://github.com/ixiehao)
- Source, downloads, and release notes: [github.com/ixiehao/ShotTessera](https://github.com/ixiehao/ShotTessera)
- Feedback and feature ideas: [open a GitHub issue](https://github.com/ixiehao/ShotTessera/issues/new/choose)
- What changed: [CHANGELOG.md](CHANGELOG.md) · Privacy promise: [PRIVACY.md](PRIVACY.md)

## At a glance

![ShotTessera flow: video frames become a contact sheet and then an exported image](docs/assets/video-to-storyboard-overview.png)

| Add video | Select useful frames | Build the sheet | Export locally |
| --- | --- | --- | --- |
| Drop one video or queue several. | Detect cuts; avoid black, blurry, and duplicate frames; prefer people when present. | Preview each tile in a 3×3 to 8×8 storyboard grid. | Save a 1920 px+ PNG or JPEG next to the source video. |

## Features

- Keeps the source video's portrait, square, or landscape composition by default; 16:9, 4:3, 1:1, 3:4, 9:16, and 21:9 are also available.
- Shows live tiles as each storyboard is assembled and processes multi-video queues sequentially.
- Supports MP4, MOV, MPEG, and more (codec support depends on macOS).
- Optionally adds timecodes and a large translucent title based on the video filename.
- Switch the interface between 中文, English, and 日本語; the chosen language is remembered.
- Saves as `video-name-shot-001.png` or `.jpg`, incrementing safely when needed.

## Private by design

All frame analysis and export happen on your Mac. ShotTessera has no account, telemetry, network client, cloud upload, Electron, FFmpeg, or Python runtime.

## License

Project code and original assets are released under the [MIT License](LICENSE). The bundled Noto Sans CJK SC Bold font is unmodified and separately licensed under the [SIL Open Font License 1.1](ThirdPartyLicenses/NotoSansCJK-OFL-1.1.txt); see [NOTICE.md](NOTICE.md). Follow applicable local laws and only process video you own or are authorised to analyse.

Contributions are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before participating.
