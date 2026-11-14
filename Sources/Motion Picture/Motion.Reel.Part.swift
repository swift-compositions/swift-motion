#if Picture
    public import Motion
    public import Picture

    extension Motion.Reel {
        /// A part of a reel: its key, how many frames it lasts, and the picture of each of its own frames.
        ///
        /// What draws the pictures may be built only when it is first needed: a part made with a function that
        /// builds its drawing calls that function once, the first time a frame of the part is drawn, and never
        /// before, so a reel of costly scenes builds only the scenes of the frames it draws. The count of frames
        /// is given beforehand, so a reel's length, its places and its positions build nothing.
        public struct Part: Sendable {
            public let key: Key
            public let frames: Cardinal
            let drawing: Drawing

            /// A part whose drawing is built the first time one of its frames is drawn.
            public init(_ key: Key, frames: Cardinal, building: @escaping @Sendable () -> @Sendable (Frame) -> Picture::Picture) {
                self.key = key
                self.frames = frames
                self.drawing = Drawing(building)
            }

            /// A part whose drawing is there already.
            public init(_ key: Key, frames: Cardinal, picture: @escaping @Sendable (Frame) -> Picture::Picture) {
                self.init(key, frames: frames, building: { picture })
            }
        }
    }

    extension Motion.Reel.Part {
        /// The picture of a frame of the part, counted from zero at its start, building the part's drawing first
        /// if no frame of it has been drawn before.
        public func picture(_ frame: Motion.Reel<Key>.Frame) -> Picture::Picture {
            drawing.drawn(frame)
        }

        /// A scene as a part whose drawing is built the first time one of its frames is drawn: its frames, each
        /// drawn from the state the scene has at the frame's center at the scene's own rate, which is the reel's
        /// when the scene is to play at its own speed.
        public init<State>(
            _ key: Key,
            scene: Motion.Scene<State>,
            building: @escaping @Sendable () -> @Sendable (State) -> Picture::Picture
        ) {
            self.init(key, frames: scene.frames) {
                let picture = building()
                return { frame in picture(scene.state(scene.rate.centre(of: Integer(Int(bitPattern: frame.position))))) }
            }
        }

        /// A scene as a part, drawn by a drawing that is there already.
        public init<State>(
            _ key: Key,
            scene: Motion.Scene<State>,
            picture: @escaping @Sendable (State) -> Picture::Picture
        ) {
            self.init(key, scene: scene, building: { picture })
        }
    }
#endif
