#if Picture
    public import Motion
    import Picture

    extension Motion.Hosting.Picture.Frames {
        /// The first frames of a motion handed over one at a time, drawn a stretch ahead: asking for a frame it
        /// does not hold makes it draw that frame and the ones after it, as many as a stretch is long, side by
        /// side, and let go of the stretch before. So asking in order, as an encoder or a loop that writes
        /// numbered files does, draws every frame once and holds one stretch at a time.
        public actor Feed<Frame: Sendable> {
            let frames: Motion.Hosting.Picture.Frames
            let count: Cardinal
            let ahead: Cardinal
            let form: Motion.Hosting.Picture.Frames.Form<Frame>
            var first: Int = 0
            var held: [Frame] = []

            init(
                _ frames: Motion.Hosting.Picture.Frames,
                count: Cardinal,
                ahead: Cardinal,
                _ form: Motion.Hosting.Picture.Frames.Form<Frame>
            ) {
                self.frames = frames
                self.count = count
                self.ahead = ahead
                self.form = form
            }
        }
    }

    extension Motion.Hosting.Picture.Frames.Feed {
        /// The frame at a position, or nil from `count` on. A stretch that fails is thrown, and is tried again
        /// when it is next asked for.
        public func frame(at position: Ordinal) async throws(Motion.Hosting.Picture.Frames.Error) -> Frame? {
            let place = Int(bitPattern: position)
            let end = Int(clamping: count)
            guard place < end else { return nil }
            if !(first..<first + held.count).contains(place) {
                held = []
                first = place
                let stretch = (place..<Swift.min(place + Int(clamping: ahead), end)).map { Ordinal(UInt($0)) }
                held = try await frames.drawn(stretch, as: form)
            }
            return held[place - first]
        }
    }
#endif
