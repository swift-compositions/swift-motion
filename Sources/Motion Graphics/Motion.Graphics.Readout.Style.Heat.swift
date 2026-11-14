#if Graphics
    public import Motion

    extension Motion.Graphics.Readout.Style {
        /// What a readout's heat adds at full heat: to the alpha of its plate's edge, and to the strength of its
        /// glow. A readout's heat is the greater of its moment's heat and finish.
        public struct Heat: Sendable, Hashable {
            public var edge: Double
            public var glow: Double

            public init(edge: Double, glow: Double) {
                self.edge = edge
                self.glow = glow
            }
        }
    }
#endif
