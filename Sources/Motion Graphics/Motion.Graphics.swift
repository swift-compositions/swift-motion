#if Graphics
    public import Motion

    extension Motion {
        /// Components drawn on screen in a motion picture: a window's chrome, a terminal's transcript and its
        /// typing, a caption, a headline, a checklist and its boxes, and a readout.
        ///
        /// Each component is a value that holds its structure (its words, its place) and a `Style` that holds
        /// every decision of its look, and each is drawn at a `Moment`, its progress values at one instant, by
        /// `Picture.init(_:at:)`. A component keeps no time: the caller's timeline makes the moments.
        public enum Graphics {}
    }

    extension Motion.Graphics {
        /// How many of n characters stand at a typed share s: the most k with k / n at most s, which is
        /// floor(s · n) taken exactly, so a share made as k / n stands k. A share at or below 0 stands none, and
        /// one at or above 1 stands all.
        static func standing(_ share: Double, of count: Int) -> Int {
            guard share > 0, count > 0 else { return 0 }
            guard share < 1 else { return count }
            let guess = Int((share * Double(count)).rounded(.down))
            let lower = Double(guess) / Double(count) > share ? guess - 1 : guess
            return Double(lower + 1) / Double(count) <= share ? lower + 1 : lower
        }
    }
#endif
