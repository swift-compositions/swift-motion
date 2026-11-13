#if Picture
    public import Motion
    public import Picture
    public import Timeline

    extension Motion.Reel {
        /// A layer laid over a span of the reel: a key the caller chooses, by which it is drawn or left out, and a
        /// `Timeline.Layer` whose lifetime is the span in seconds of the reel's time and whose content draws a frame
        /// of the reel. More than one layer may carry the same key.
        public struct Layer: Sendable {
            public let key: Key
            public let timeline: Timeline.Layer<@Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture>

            public init(_ key: Key, _ timeline: Timeline.Layer<@Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture>) {
                self.key = key
                self.timeline = timeline
            }

            /// A layer of this key over the span, drawing each frame with `content`.
            public init(
                _ key: Key,
                over lifetime: Range<Rational>,
                content: @escaping @Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture
            ) {
                self.init(key, Timeline.Layer(content, over: lifetime))
            }
        }
    }
#endif
