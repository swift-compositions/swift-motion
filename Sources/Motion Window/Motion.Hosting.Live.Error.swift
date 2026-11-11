public import Motion
public import Motion_Clock

extension Motion.Hosting.Live {
    public enum Error: Swift.Error, Hashable, Sendable {
        /// The size is not whole points on the main screen, narrower than 16 points, or more than the
        /// window server can be told.
        case size(width: Cardinal, height: Cardinal)
        /// The process's clock could not be frozen or moved.
        case clock(Motion.Clock.Error)
        /// The window could not be found to capture.
        case window(String)
        /// No capture of the frame showed the frame's own fence.
        case capture(frame: Ordinal, String)
        /// Captures of the frame showed its fence but no two in a row were the same picture.
        case unsettled(frame: Ordinal)
        /// The host was closed.
        case closed
    }
}
