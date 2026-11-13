#if Graphics
    public import Motion

    extension Motion.Graphics.Window {
        /// A window at an instant: how much of it shows, 0 none, 1 all of it.
        public struct Moment: Sendable, Hashable {
            public var shown: Double

            public init(shown: Double) {
                self.shown = shown
            }
        }
    }

    extension Motion.Graphics.Window.Moment {
        /// Nothing of the window.
        public static let hidden = Self(shown: 0)

        /// The whole window.
        public static let resting = Self(shown: 1)
    }
#endif
