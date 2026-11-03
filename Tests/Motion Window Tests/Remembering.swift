import AppKit
import SwiftUI

/// An AppKit view that keeps the shade it was made with, as AppKit-backed views keep their own state.
struct Remembering: NSViewRepresentable {
    let shade: Double
}

extension Remembering {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: shade, alpha: 1).cgColor
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
