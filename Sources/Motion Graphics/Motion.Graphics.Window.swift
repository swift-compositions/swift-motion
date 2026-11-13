#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A window's chrome: an edge with round corners around a frame, a title bar with its traffic lights and a
        /// title in its middle, a rule under the bar, and the body below it.
        public struct Window: Sendable {
            /// The window's outer edge.
            public var frame: Picture.Plane.Rectangle

            /// The words in the title bar.
            public var title: Swift.String

            public var style: Style

            public init(frame: Picture.Plane.Rectangle, title: Swift.String, style: Style) {
                self.frame = frame
                self.title = title
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Window {
        /// The body: the frame below the title bar and its rule, where the window's content stands.
        public var body: Picture.Plane.Rectangle {
            let top = frame.lly.underlying + style.bar + style.line
            return Picture.Plane.Rectangle(llx: frame.llx, lly: .init(Swift.min(top, frame.ury.underlying)), urx: frame.urx, ury: frame.ury)
        }
    }
#endif
