import SwiftUI

extension Motion.Hosting.Live.Fence {
    /// The band: sixteen cells, each black, red, green or blue, spelling `number` in base 4.
    struct Band {
        let fence: Motion.Hosting.Live.Fence
        let cell: Double
        let height: Double
    }
}

extension Motion.Hosting.Live.Fence.Band: SwiftUI.View {
    var body: some SwiftUI.View {
        let digits = Motion.Hosting.Window.digits(fence.number)
        HStack(spacing: 0) {
            ForEach(0..<16, id: \.self) { index in Motion.Hosting.Window.colour(digits[index]).frame(width: cell, height: height) }
        }
        .frame(width: cell * 16, height: height)
    }
}
