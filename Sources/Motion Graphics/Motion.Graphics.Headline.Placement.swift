#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Headline {
        /// Where a line stands at an instant: its text at the fitted size, the middle of its baseline, and the
        /// slot that clips it.
        public struct Placement: Sendable, Hashable {
            public var text: Typesetting.Text
            public var point: Picture.Plane.Point<2>
            public var slot: Picture.Plane.Path

            public init(text: Typesetting.Text, point: Picture.Plane.Point<2>, slot: Picture.Plane.Path) {
                self.text = text
                self.point = point
                self.slot = slot
            }
        }
    }
#endif
