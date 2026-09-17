# Privacy

ShotTessera processes a video entirely on the device that opens it.

- No user account or analytics SDK is included.
- No video, frame, path, face-detection result, or generated storyboard is sent over the network.
- The app does not keep an internal media library. It reads the selected file and writes only to the location chosen in the export panel.
- Apple's AVFoundation and Vision frameworks perform decoding and people/face detection locally.
- To check for a newer app version, the app reads only public latest-release metadata from GitHub. The request contains no video, file path, frame, account, or analytics data; downloading happens only after the user chooses it in their browser.

If this changes in a future release, the change must be documented here and in the release notes before it ships.
