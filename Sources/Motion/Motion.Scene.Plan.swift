public import Raster

extension Motion.Scene {
    /// What to render: each distinct state once, and for each frame the position in `states` of the state it shows.
    public struct Plan: Sendable {
        public let states: [State]
        public let shows: [Ordinal]
    }
}
