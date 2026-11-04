# swift-motion

Use this package when you render a video frame by frame from SwiftUI views on macOS and need exact timing and a correctly tagged MP4. Describe the animation as a `Scene` at a `Frame.Rate`, draw each state with `Hosting.Cache` or `Hosting.Window` into a `Raster`, and write the frames with `Encoding`. For timecodes alone use swift-smpte-st-12, and for colour signal code points use swift-itu-t-h-273.

## Laws

- A `Frame.Rate` is an exact fraction kept in lowest terms, so 29.97 is 30000/1001. Frame starts and centres are exact, and both map back to their own frame.
- `Frame.Rate.samples(in:at:)` gives each frame its share of audio samples so that any run of frames adds up to the exact floor of its duration. Five frames at 30000/1001 hold exactly 8008 samples at 48 kHz.
- `Frame.Rate.timecode(of:)` is drop-frame at 30000/1001 and 60000/1001, non-drop at whole rates, and nil at a rate SMPTE ST 12 has no nominal rate for, such as 15.
- `Scene.plan` samples the state at the centre of each frame. It lists each distinct state once, in the order first shown, so each is drawn only once.
- `Render.check(_:render:)` renders every frame twice and reports the first that differs, with the PSNR between the two. `Render.Ordered` hands on frames that finish out of order in order, each as soon as all frames before it have arrived.
- A `Raster` is BGRA8, premultiplied, in sRGB. One with a colour channel above its alpha is refused. Two rasters are equal when their pixels are, whatever padding their rows carry, and `Raster.top(_:)` keeps the padding.
- `Raster.psnr(_:_:)` compares colour channels only and leaves alpha aside. Equal pictures give infinity.
- `Encoding` writes H.264 into MP4. The movie's timescale is the rate's numerator, so every frame lasts exactly the denominator in ticks: 1001 of 30000 at 29.97. By default frames are tagged 1-13-1 at limited range, sRGB carried through the BT.709 matrix, at a bit rate of four bits per pixel per second.
- A signal AVFoundation has no name for, or one at full range, is refused before anything is written, rather than written untagged. A frame that is missing or of another size stops the write.
- `Encoding.mux(_:_:to:)` joins a picture and a sound without re-encoding either. The sound is cut to the picture's length, and the picture keeps its colour tag, timescale and frame durations.
- Both hosts draw each frame in a fresh hosting view, so no view state carries over from the frame before, and they reuse one window while the size stays the same. `Hosting.Cache.forget()` and `Hosting.Window.forget()` make the next frame start from a new window.
- `Hosting.Cache` draws on the CPU at one pixel per point and needs no permission. Its blur and shadows are the software versions, slightly different from the screen's.
- `Hosting.Window` draws through the window server like the screen does and needs Screen Recording permission. Only one process should capture at a time. Its animations are frozen, so a spinning view captures the same every time, and the picture comes back pixel for pixel. Sizes must be whole points on the main screen and at least 16 points wide, or the result is nil. Captures take turns, and each one is checked to show its own frame before it is returned.
