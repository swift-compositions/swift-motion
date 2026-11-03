import SwiftUI

/// A view that turns black while the pointer is over it.
struct Hovering: View {
    @State var hovering = false
}

extension Hovering {
    var body: some View {
        Color(white: hovering ? 0 : 1).onHover { hovering = $0 }
    }
}
