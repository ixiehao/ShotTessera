# Architecture

ShotTessera is a native macOS storyboard generator. Its deliberately small
architecture uses only Apple system frameworks: SwiftUI, AVFoundation, Vision,
CoreGraphics, ImageIO, and AppKit. There are no package dependencies,
media sidecars, bundled ML models, web services, analytics SDKs, or runtime
downloads.

## Privacy boundary

The selected video stays on the Mac. AVFoundation decodes it locally and Vision
runs its face and human-rectangle requests on-device. The only persistent output
is the PNG or JPEG the user chooses to save. ShotTessera has no account, network
client, upload path, or internal media library. See [PRIVACY.md](../PRIVACY.md)
for the user-facing promise.

## Processing pipeline

```text
video URL
  -> AVAssetImageGenerator samples a bounded set of frames
  -> PixelMetrics makes a 48 x 48 luminance histogram, exposure/black score,
     edge-detail score, and perceptual fingerprint
  -> FrameSelection finds histogram-based shot ranges, ranks a representative
     from each range, supplements short-cut videos by time bucket, and removes
     near duplicates
  -> Vision scores only promising candidates for faces and full-body people
  -> selected source frames are encoded and StoryboardComposer lays them out
     as rounded 16:9 cards
  -> ImageIO writes the requested PNG or JPEG
```

`ExportSettings` constrains the grid to the UI's 3 x 3 through 9 x 9 choices
and clamps exported width to at least 1920 px. Rendering uses CoreGraphics, so
the final image is composed in memory without an intermediate image editor.

## Selection behavior

Scene boundaries come from differences between compact luminance histograms.
Candidates are rejected or penalized when they are almost black, too dim,
low-detail (a blur proxy), or perceptually close to an already chosen image.
Face close-ups and large human rectangles receive an additional preference
score. When a video does not contain people or has too few detectable cuts,
the selector gracefully falls back to good, time-distributed visual frames. A
strict pass removes near duplicates; a final relaxed time-bucket pass is only
used to fill every requested cell on sparse, long-shot source material.

## Known limits

- This is heuristic selection, not semantic understanding: it cannot promise
  the most dramatic, beautiful, or narratively important image.
- Very dark films, rapid edits, fades, animation, and footage with deliberate
  motion blur can make shot detection or quality scoring less reliable.
- Vision's face/person detection can miss subjects because of angle, scale,
  occlusion, costume, or lighting; it is a preference rather than a guarantee.
- Frame support and decode performance are determined by the codecs available
  in the user's macOS installation. Long or high-resolution videos can take
  time, though sampling is capped to keep work bounded.
- The renderer currently targets 16:9 cards. Portrait and unusual aspect-ratio
  video is aspect-filled and may be cropped at the edges.

## Contributor notes

- Preserve the no-dependency, no-network design. Discuss any new entitlement,
  package, model, telemetry, or remote request before adding it.
- Keep video access scoped to a user-selected URL and keep derived media
  ephemeral unless the user explicitly exports it.
- Changes to selection thresholds should include deterministic unit tests for
  scene separation, duplicate rejection, and fallback behavior.
- Keep exported images at or above 1920 px wide and test all grid sizes from
  3 x 3 to 9 x 9.
- If privacy-relevant behavior changes, update both this document and
  [PRIVACY.md](../PRIVACY.md) in the same change.
