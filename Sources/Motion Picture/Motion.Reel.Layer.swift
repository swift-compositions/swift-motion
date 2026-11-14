#if Picture
    public import Motion
    public import Picture
    public import Timeline

    extension Motion.Reel {
        /// A layer laid over a span of the reel: a key the caller chooses, by which it is drawn or left out, its
        /// lifetime, the span in seconds of the reel's time it is drawn over, and what draws a frame of the reel.
        /// More than one layer may carry the same key.
        ///
        /// What draws it may be built only when it is first needed, as a part's is: a layer made with a function
        /// that builds its drawing calls that function once, the first time a frame it is laid over is drawn, and
        /// never before. The building may fail as `Typesetting.Text` does, when words do not set; it is still
        /// called once, and every frame the layer is laid over then fails with `Motion.Reel.Error.building` of
        /// the layer's key and that failure.
        public struct Layer: Sendable {
            public let key: Key
            public let lifetime: Range<Rational>
            let drawing: Motion.Reel<Key>.Drawing

            /// A layer of this key over the span, whose drawing is built the first time a frame it is laid over
            /// is drawn.
            public init(
                _ key: Key,
                over lifetime: Range<Rational>,
                building: @escaping @Sendable () throws(Typesetting.Error) -> @Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture
            ) {
                self.key = key
                self.lifetime = lifetime
                self.drawing = Drawing(building)
            }

            /// A layer of this key over the span, drawing each frame with `content`.
            public init(
                _ key: Key,
                over lifetime: Range<Rational>,
                content: @escaping @Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture
            ) {
                self.init(key, over: lifetime, building: { content })
            }

            /// A layer of this key over a `Timeline.Layer`'s lifetime, drawing each frame with its content.
            public init(_ key: Key, _ timeline: Timeline.Layer<@Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture>) {
                self.init(key, over: timeline.lifetime, content: timeline.content)
            }
        }
    }

    extension Motion.Reel.Layer {
        /// Whether the layer is drawn at an instant of the reel: its lifetime holds it, the end not included.
        public func alive(at time: Rational) -> Bool {
            lifetime.contains(time)
        }

        /// The layer's picture of a frame of the reel, building its drawing first if no frame has been drawn
        /// with it before. It fails with `.building` of the layer's key when the drawing could not be built.
        public func picture(_ frame: Motion.Reel<Key>.Frame) throws(Motion.Reel<Key>.Error) -> Picture::Picture {
            do throws(Typesetting.Error) {
                return try drawing.drawn()(frame)
            } catch {
                throw .building(key, error)
            }
        }
    }
#endif
