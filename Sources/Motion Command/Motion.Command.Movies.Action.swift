#if Command && canImport(AVFoundation)
    public import Motion

    extension Motion.Command.Movies {
        /// What a command does with movie files.
        public enum Action: Swift.String, Sendable, Hashable, CaseIterable {
            /// Sheets of a reference movie and another movie side by side at the same instants, as PNGs.
            case compare

            /// A stretch of a sound laid under a movie's picture, written as a new movie.
            case score

            /// A movie made smaller for sharing.
            case reduce
        }
    }
#endif
