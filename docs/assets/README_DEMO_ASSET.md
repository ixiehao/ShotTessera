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

No third-party stock footage, photographs, or video clips are used in the
README. A future real-world case study must come from footage created or
explicitly licensed by the project and include a source-and-permission record
before it is published.

## Installation guides

`install-guide-background.png`, `install-guide-en.jpg`,
`install-guide-zh.jpg`, and `install-guide-ja.jpg` are project assets. The
background and explanatory layout are original project work. The three visual
cards deliberately use the approved, real ShotTessera screenshots in
`install-screen-dmg.png` and `install-screen-launch.png`, rather than drawings
of Finder, the Applications folder, or the app.

Those screenshots show only ShotTessera's installer or its own empty-state UI;
they contain no user files, third-party apps, or third-party media. They are
provided by the project owner for this documentation and are released with the
other original project assets under the [MIT License](../../LICENSE).

To regenerate a guide on macOS:

```sh
swift scripts/create_install_guide.swift \
  docs/assets/install-guide-background.png zh \
  docs/assets/install-screen-dmg.png \
  docs/assets/install-screen-launch.png \
  docs/assets/install-guide-zh.jpg
```

Replace `zh` with `en` or `ja` for the other localized guides. These original
project assets are released under the [MIT License](../../LICENSE).
