#if Graphics
    public import Motion

    extension Motion.Graphics.Readout {
        /// A readout at an instant: how far it has grown in, 0 to 1 with a little overshoot; how hot it reads and
        /// how finished, 0 to 1 each; a flash over its plate, 1 falling to 0; how much of its light is on, 0 to
        /// 1; and how far it hangs askew, in radians about its pivot, and has dropped, in pixels.
        public struct Moment: Sendable, Hashable {
            public var shown: Double
            public var heat: Double
            public var finished: Double
            public var flash: Double
            public var light: Double
            public var tilt: Double
            public var drop: Double

            public init(
                shown: Double = 1,
                heat: Double = 0,
                finished: Double = 0,
                flash: Double = 0,
                light: Double = 1,
                tilt: Double = 0,
                drop: Double = 0
            ) {
                self.shown = shown
                self.heat = heat
                self.finished = finished
                self.flash = flash
                self.light = light
                self.tilt = tilt
                self.drop = drop
            }
        }
    }

    extension Motion.Graphics.Readout.Moment {
        /// Nothing of the readout.
        public static let hidden = Self(shown: 0)

        /// The readout in place, cold, lit and level.
        public static let resting = Self()
    }
#endif
