#if Graphics
    public import Motion

    extension Motion.Graphics.Marquee {
        /// How a row's words are drawn: filled, or outlined by a pen of a width.
        public enum Face: Sendable, Hashable {
            case filled
            case outlined(Double)
        }
    }
#endif
