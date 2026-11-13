#if Picture
    public import Motion
    public import Picture
    public import Timeline

    extension Motion.Reel {
        /// A layer of a reel: a `Timeline.Layer` whose lifetime is a span of the reel's time in seconds and whose
        /// content draws the picture of a frame of the reel, laid over the part beneath while the frame's centre
        /// is in the span.
        public typealias Layer = Timeline.Layer<@Sendable (Frame) -> Picture::Picture>
    }
#endif
