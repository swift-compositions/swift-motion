#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Window {
        /// A window's look: the title's ink, the plate its frame is, the bar's height, the rule under the bar and
        /// the traffic lights.
        public struct Style: Sendable {
            /// The title's font, size and colour.
            public var title: Motion.Graphics.Ink

            /// The window's body and edge round its frame; a clear fill draws no body.
            public var plate: Motion.Graphics.Plate

            /// The height of the title bar, from the frame's top to the rule.
            public var bar: Double

            /// The rule's colour and its height.
            public var rule: Picture.Color

            public var line: Double

            public var lights: Lights

            public init(
                title: Motion.Graphics.Ink,
                plate: Motion.Graphics.Plate,
                bar: Double,
                rule: Picture.Color,
                line: Double,
                lights: Lights
            ) {
                self.title = title
                self.plate = plate
                self.bar = bar
                self.rule = rule
                self.line = line
                self.lights = lights
            }
        }
    }
#endif
