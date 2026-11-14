#if Graphics
    import Motion
    import Picture
    import Testing

    @testable import Motion_Graphics

    @Suite struct `Spinner Tests` {
        static let centre = Picture.Plane.Point<2>([100, 80])

        static let spinner = Motion.Graphics.Spinner(
            at: centre,
            radius: 40,
            style: .init(pen: 8, track: Picture.Color(gray: 1, alpha: 0.2), ink: Picture.Color(hex: 0xFF8800), glow: .init(deviation: 6, strength: 0.4, flash: 0.6))
        )

        @Test func `a spinner hidden draws nothing, and at rest or filled whole it is the whole ring`() {
            #expect(Picture(Self.spinner, at: .hidden) == .empty)
            let ring = Picture.Plane.Path(Picture.Plane.Circle(center: Self.centre, radius: .init(40)))
            #expect(Self.spinner.arc(at: .resting) == ring)
            #expect(Self.spinner.arc(at: .init(turn: 0.37, filled: 1)) == ring)
            #expect(Picture(Self.spinner, at: .init(turn: 0.2, filled: 3)) == Picture(Self.spinner, at: .init(turn: 0.2, filled: 1)))
        }

        @Test func `the arc starts at the top turned by the moment and covers the share filled`() throws {
            #expect(Self.spinner.arc(at: .init(filled: 0)) == nil)
            #expect(Picture(Self.spinner, at: .init(filled: 0)).elements.count == 1)
            let quarter = try #require(Self.spinner.arc(at: .init(turn: 0, filled: 0.25)))
            let start = try #require(quarter.subpaths.first?.startPoint)
            #expect(Swift.abs(start[0] - 100) < 1e-9 && Swift.abs(start[1] - 40) < 1e-9)
            let turned = try #require(Self.spinner.arc(at: .init(turn: 0.25, filled: 0.25))?.subpaths.first?.startPoint)
            #expect(Swift.abs(turned[0] - 140) < 1e-9 && Swift.abs(turned[1] - 80) < 1e-9)
            let length = { (share: Double) in Self.spinner.arc(at: .init(filled: share))?.subpaths.first?.length().underlying ?? 0 }
            #expect(Swift.abs(length(0.25) - 2 * Double.pi * 40 / 4) < 1e-6)
            #expect(length(0.25) < length(0.5) && length(0.5) < length(0.75))
        }

        @Test func `a spinner fades by how much shows`() {
            guard case .layer(let layer) = Picture(Self.spinner, at: .init(shown: 0.5, filled: 0.4)).elements.first else {
                Issue.record("a spinner partly shown is a layer")
                return
            }
            #expect(layer.opacity == 0.5)
        }

        @Test func `its glow spares a mask of the caller's, and at a strength of 0 there is no glow layer`() throws {
            let soft: Picture = [.glow(.white, center: Self.centre, radius: 36)]
            var style = Self.spinner.style
            let masked = Motion.Graphics.Spinner(at: Self.centre, radius: 40, style: style, mask: soft)
            let picture = Picture(masked, at: .init(filled: 0.5))
            guard case .layer(let light) = picture.elements.last, case .layer(let spared) = light.content.elements.last else {
                Issue.record("the glow is a layer that spares its mask")
                return
            }
            #expect(spared.content == soft && spared.operator == .destinationOut)
            style.glow = .init(deviation: 6, strength: 0)
            let dark = Picture(Motion.Graphics.Spinner(at: Self.centre, radius: 40, style: style), at: .init(filled: 0.5))
            #expect(dark.elements.allSatisfy { if case .layer = $0 { false } else { true } })
            #expect(dark.elements.count == 2)
            style.glow = nil
            #expect(Picture(Motion.Graphics.Spinner(at: Self.centre, radius: 40, style: style), at: .init(filled: 0.5)) == dark)
        }
    }
#endif
