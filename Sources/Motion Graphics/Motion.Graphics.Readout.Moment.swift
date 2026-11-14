#if Graphics
    public import Motion

    extension Motion.Graphics.Readout {
        /// A readout at an instant: the count it reads; how far it has grown in, 0 to 1 with a little overshoot;
        /// how hot it reads and how finished, 0 to 1 each; a flash over its plate, 1 falling to 0; and how much of
        /// its light is on, 0 to 1, which dims it without shrinking it or emptying its bar as `shown` does.
        public struct Moment: Sendable, Hashable {
            /// The count, which a readout that counts takes from its timeline; above the total it reads the total.
            public var count: Cardinal

            public var shown: Double

            public var heat: Double

            public var finished: Double

            public var flash: Double

            public var light: Double

            public init(count: Cardinal, shown: Double = 1, heat: Double = 0, finished: Double = 0, flash: Double = 0, light: Double = 1) {
                self.count = count
                self.shown = shown
                self.heat = heat
                self.finished = finished
                self.flash = flash
                self.light = light
            }
        }
    }

    extension Motion.Graphics.Readout.Moment {
        /// Nothing of the readout.
        public static let hidden = Self(count: .zero, shown: 0)

        /// The readout in place at a count, cold and lit.
        public static func resting(_ count: Cardinal) -> Self {
            Self(count: count)
        }
    }
#endif
