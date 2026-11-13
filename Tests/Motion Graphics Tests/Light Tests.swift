#if Graphics
    import Motion
    import Picture
    import Testing

    @testable import Motion_Graphics

    @Suite struct `Light Tests` {
        static let box = Picture.Plane.Rectangle(llx: 100, lly: 50, urx: 500, ury: 150)

        static func glint(slant: Double = 0) -> Motion.Graphics.Glint {
            Motion.Graphics.Glint(
                over: Picture.Plane.Path(box),
                style: .init(color: .white, strength: 0.85, width: 160, slant: slant, glow: .init(deviation: 10, strength: 0.8))
            )
        }

        @Test func `a glint sets out before its shape and ends past it, and draws nothing then`() throws {
            #expect(Picture(Self.glint(), at: .hidden) == .empty)
            #expect(Picture(Self.glint(), at: .resting) == .empty)
            #expect(Picture(Self.glint(), at: .init(swept: 0.5, light: 0)) == .empty)
            #expect(Picture(Self.glint(), at: .init(swept: 0.5)) != .empty)
            #expect(Self.glint().middle(at: .hidden).map { Swift.abs($0 - (100 - 80)) < 1e-9 } == true, "\(String(describing: Self.glint().middle(at: .hidden)))")
            #expect(Self.glint().middle(at: .resting).map { Swift.abs($0 - (500 + 80)) < 1e-9 } == true, "\(String(describing: Self.glint().middle(at: .resting)))")
            let band = try #require(Self.glint().band(at: .init(swept: 0.5)))
            #expect(Swift.abs((band.start[0] + band.end[0]) / 2 - 300) < 1e-9)
        }

        @Test func `a glint's middle never goes back as it sweeps, at any slant`() throws {
            for slant in [0, 0.4, -1.1, 2.5] {
                let glint = Self.glint(slant: slant)
                let middles = try stride(from: 0.0, through: 1, by: 0.05).map { try #require(glint.middle(at: .init(swept: $0))) }
                #expect(zip(middles, middles.dropFirst()).allSatisfy { $0 < $1 })
            }
        }

        static let twinkle = Motion.Graphics.Twinkle(
            at: Picture.Plane.Point<2>([200, 200]),
            style: .init(
                rays: [.init(angle: 0, length: 120, width: 3), .init(angle: Double.pi / 2, length: 120, width: 3), .init(angle: Double.pi / 4, length: 38, width: 3)],
                color: .white,
                core: Picture.Color(hex: 0xFFC060),
                radius: 50,
                turn: 0.6
            )
        )

        @Test func `a twinkle shines from nothing to whole halfway and back to nothing`() {
            #expect(Picture(Self.twinkle, at: .hidden) == .empty)
            #expect(Picture(Self.twinkle, at: .resting) == .empty)
            #expect(Motion.Graphics.Twinkle.Moment(shone: 0.5).shine == 1)
            #expect(Motion.Graphics.Twinkle.Moment(shone: 0.25).shine < Motion.Graphics.Twinkle.Moment(shone: 0.5).shine)
            guard case .layer(let layer) = Picture(Self.twinkle, at: .init(shone: 0.5)).elements.first else {
                Issue.record("a twinkle adds its light in a layer")
                return
            }
            #expect(layer.content.elements.count == 3 + 1)
        }
    }
#endif
