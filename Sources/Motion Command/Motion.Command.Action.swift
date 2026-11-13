#if Command
    public import Motion

    extension Motion.Command {
        /// What a command writes of a reel.
        public enum Action: Swift.String, Sendable, Hashable, CaseIterable {
            /// Contact sheets and stills, as PNGs.
            case sheet

            /// Every frame as a PNG, numbered from zero.
            case frames

            /// Every frame as an H.264 MP4.
            case movie
        }
    }
#endif
