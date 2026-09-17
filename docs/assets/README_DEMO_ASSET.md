# README Demo Asset

`video-to-storyboard-demo.gif` and its PNG fallback are original project
assets. They are rendered by `scripts/create_readme_demo.swift` from gradients,
geometric shapes, and project-authored text only.

They contain no third-party video clips, photographs, logos, stock artwork,
people, places, or downloaded visual assets. The files are released with the
rest of the project's original assets under the [MIT License](../../LICENSE).

To regenerate the animation on macOS:

1. Run `swift scripts/create_readme_demo.swift /tmp/shottessera-demo-frames`.
2. Use FFmpeg to convert the numbered PNG frames to a compact GIF.

The committed GIF is 960 × 540, contains 12 frames, and is kept intentionally
small for the README's first-screen loading performance.

## Installation guides

`install-guide-background.png`, `install-guide-en.jpg`,
`install-guide-zh.jpg`, and `install-guide-ja.jpg` are original project
assets. The background was generated solely for this project without using a
third-party image as a reference; the instructional panels, icons, and all
text are rendered from project-authored code in
`scripts/create_install_guide.swift`. They do not reproduce Apple screenshots,
Apple artwork, or third-party app artwork.

To regenerate a guide on macOS:

```sh
swift scripts/create_install_guide.swift \
  docs/assets/install-guide-background.png zh docs/assets/install-guide-zh.jpg
```

Replace `zh` with `en` or `ja` for the other localized guides. These original
project assets are released under the [MIT License](../../LICENSE).
