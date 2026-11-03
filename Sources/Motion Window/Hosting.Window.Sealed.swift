import AppKit

extension Hosting.Window {
    /// A window that drops every pointer event and reports the pointer far outside it, so no
    /// view it hosts ever learns where the pointer is.
    final class Sealed: NSWindow {
        override var mouseLocationOutsideOfEventStream: NSPoint { NSPoint(x: -100_000, y: -100_000) }

        override func sendEvent(_ event: NSEvent) {
            switch event.type {
            case .mouseMoved, .mouseEntered, .mouseExited, .cursorUpdate, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
                .rightMouseDown, .rightMouseUp, .rightMouseDragged, .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel:
                return
            default:
                super.sendEvent(event)
            }
        }
    }
}
