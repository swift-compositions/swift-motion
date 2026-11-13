import Motion
import Synchronization

extension Motion.Hosting.Picture.Frames {
    /// What the threads that draw one run of frames share: the place of the next frame to take, the frames
    /// made so far, and the first failure.
    final class Progress<Frame: Sendable>: Sendable {
        let next = Atomic<Int>(0)
        let results: Mutex<(frames: [Frame?], failure: Motion.Hosting.Picture.Frames.Error?)>

        init(count: Int) {
            self.results = Mutex(([Frame?](repeating: nil, count: count), nil))
        }
    }
}
