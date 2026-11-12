import Observation

extension Motion.Hosting.Live {
    /// The number the band below the picture spells, changed in the same turn as the frame's own change so
    /// that a capture showing the number shows the change.
    @MainActor @Observable final class Fence {
        var number = 0
    }
}
