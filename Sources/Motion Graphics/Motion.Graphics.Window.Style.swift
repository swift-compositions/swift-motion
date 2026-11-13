#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Window {
        /// A window's look: the title's ink, the corners' radius, the bar's height, the width of the edge and of
        /// the rule, their colours, the body's fill and the traffic lights.
        public struct Style: Sendable {
            /// The title's font, size and colour.
            public var title: Motion.Graphics.Ink

            /// The radius of the frame's corners.
            public var radius: Double

            /// The height of the title bar, from the frame's top to the rule.
            public var bar: Double

            /// The width of the edge's stroke and the height of the rule.
            public var line: Double

            public var edge: Picture.Color
            public var rule: Picture.Color

            /// The fill inside the edge; a clear fill draws nothing.
            public var fill: Picture.Color

            public var lights: Lights

            public init(
                title: Motion.Graphics.Ink,
                radius: Double,
                bar: Double,
                line: Double,
                edge: Picture.Color,
                rule: Picture.Color,
                fill: Picture.Color,
                lights: Lights
            ) {
                self.title = title
                self.radius = radius
                self.bar = bar
                self.line = line
                self.edge = edge
                self.rule = rule
                self.fill = fill
                self.lights = lights
            }
        }
    }
#endif
