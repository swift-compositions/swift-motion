#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Window {
        /// A window's look: the title's ink, the frame's corners, the bar's height, the width of the edge and of
        /// the rule, their colours, the body's surface and the traffic lights.
        public struct Style: Sendable {
            /// The title's font, size and colour.
            public var title: Motion.Graphics.Ink

            public var corners: Motion.Graphics.Corners

            /// The height of the title bar, from the frame's top to the rule.
            public var bar: Double

            /// The width of the edge's stroke and the height of the rule.
            public var line: Double

            public var edge: Picture.Color
            public var rule: Picture.Color

            /// What the body inside the edge is made of; a clear fill draws nothing.
            public var surface: Motion.Graphics.Surface

            public var lights: Lights

            public init(
                title: Motion.Graphics.Ink,
                corners: Motion.Graphics.Corners,
                bar: Double,
                line: Double,
                edge: Picture.Color,
                rule: Picture.Color,
                surface: Motion.Graphics.Surface,
                lights: Lights
            ) {
                self.title = title
                self.corners = corners
                self.bar = bar
                self.line = line
                self.edge = edge
                self.rule = rule
                self.surface = surface
                self.lights = lights
            }
        }
    }
#endif
