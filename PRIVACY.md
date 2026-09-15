# Privacy

FrameWeave processes a video entirely on the device that opens it.

- No user account or analytics SDK is included.
- No video, frame, path, face-detection result, or generated storyboard is sent over the network.
- The app does not keep an internal media library. It reads the selected file and writes only to the location chosen in the export panel.
- Apple's AVFoundation and Vision frameworks perform decoding and people/face detection locally.

If this changes in a future release, the change must be documented here and in the release notes before it ships.
