#if Picture
    public import Motion
    public import Picture

    extension Motion.Reel {
        /// A part of a reel: its key, how many frames it lasts, and the picture of each of its own frames.
        public struct Part: Sendable {
            public let key: Key
            public let frames: Cardinal
            public let picture: @Sendable (Frame) -> Picture::Picture

            public init(_ key: Key, frames: Cardinal, picture: @escaping @Sendable (Frame) -> Picture::Picture) {
                self.key = key
                self.frames = frames
                self.picture = picture
            }
        }
    }

    extension Motion.Reel.Part {
        /// A scene as a part: its frames, each drawn from the state the scene has at the frame's centre at the
        /// scene's own rate, which is the reel's when the scene is to play at its own speed.
        public init<State>(
            _ key: Key,
            scene: Motion.Scene<State>,
            picture: @escaping @Sendable (State) -> Picture::Picture
        ) {
            self.init(key, frames: scene.frames) { frame in
                picture(scene.state(scene.rate.centre(of: Integer(Int(bitPattern: frame.position)))))
            }
        }
    }
#endif
