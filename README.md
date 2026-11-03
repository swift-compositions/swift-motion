# swift-motion

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Render real app views to video, frame for frame the same on every run.

## Overview

`Motion` is the Foundation-free core:

- `Frame.Rate`: an exact rational rate. Frames have integer indices; their times are exact. Audio sample counts never drift, and the SMPTE ST 12 timecode follows from the rate.
- `Raster`: BGRA8 premultiplied sRGB pixels. Equality ignores row padding, and PSNR counts colour channels only.
- `Scene` and its `Plan`: state first. Time maps to a hashable state, and each distinct state is rendered once.
- `Render.check`: the render contract, which renders each frame twice and compares the results.
- `Render.Ordered`: ordered fan-in, which hands each frame on as soon as every frame before it has arrived.

The adapters:

- `Motion Encoding`: `Encoding` writes H.264 MP4. The timescale is the rate's own, and the ITU-T H.273 colour tag defaults to 1-13-1 for frames rendered in sRGB. It also muxes a sound in without re-encoding.
- `Motion Window`: `Hosting.Window` draws a SwiftUI view the way the screen does, on the GPU, and captures it.
  - A fresh hosting view each frame, with its layer clock frozen.
  - A fence band that confirms each capture is this frame.
  - Capture at the window's own pixel size, so nothing is resampled.
  - Needs Screen Recording permission, and one capturing process at a time.
- `Motion Cache`: `Hosting.Cache` draws on the CPU with `cacheDisplay`. It is the fallback where Screen Recording isn't granted.

```swift
import Motion_Encoding
import Motion_Window

let encoding = Encoding(width: 1920, height: 1080, rate: .thirty)
try await encoding.write(frames: 900, to: url) { index in
    await Hosting.Window.raster(Stage(at: Frame.Rate.thirty.centre(of: index)), width: 1920, height: 1080)
}
```

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-compositions/swift-motion.git", branch: "main")
]
```

## License

This package is licensed under the Apache License 2.0. See [LICENSE.md](LICENSE.md) for details.
