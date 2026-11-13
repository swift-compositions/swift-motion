#if Graphics
    import Motion
    import Picture
    import Testing

    @testable import Motion_Graphics

    @Suite struct `Shockwave Tests` {
        static let shockwave = Motion.Graphics.Shockwave(
            at: Picture.Plane.Point<2>([300, 200]),
            style: .init(
                radius: 20,
                reach: 600,
                pen: 30,
                least: 4,
                color: .white,
                finish: Picture.Color(hex: 0xB9F8DA),
                fall: 2,
                trail: .init(count: 3, lag: 0.06, fade: 0.6),
                deviation: 12,
                strength: 1
            )
        )

        /// The moments the lead ring is still out: its own spread is the moment's times 1 + 3 × 0.06.
        static let spreads = stride(from: 0.01, to: 1 / 1.18, by: 0.01).map { $0 }

        @Test func `a shockwave not yet thrown or gone by draws nothing`() {
            #expect(Picture(Self.shockwave, at: .hidden) == .empty)
            #expect(Picture(Self.shockwave, at: .resting) == .empty)
            #expect(Picture(Self.shockwave, at: .init(spread: 1.5)) == .empty)
            #expect(Picture(Self.shockwave, at: .init(spread: 0.4)) != .empty)
        }

        @Test func `its ring never shrinks and its light falls to nothing by the end`() throws {
            let leads = try Self.spreads.map { try #require(Self.shockwave.rings(at: .init(spread: $0)).first) }
            #expect(zip(leads, leads.dropFirst()).allSatisfy { $0.radius < $1.radius })
            #expect(zip(leads, leads.dropFirst()).allSatisfy { $0.color.alpha >= $1.color.alpha })
            #expect(zip(leads, leads.dropFirst()).allSatisfy { $0.pen > $1.pen })
            #expect(leads.last.map { $0.color.alpha < 0.01 } == true)
            #expect(try #require(Self.shockwave.rings(at: .init(spread: 0.8474)).first).color.alpha < 1e-6)
            let last = Self.shockwave.rings(at: .init(spread: 0.999_999))
            #expect(last.allSatisfy { $0.color.alpha < 1e-6 })
        }

        @Test func `its echoes trail it, each smaller and fainter than the ring before`() {
            let rings = Self.shockwave.rings(at: .init(spread: 0.5))
            #expect(rings.count == 4)
            #expect(zip(rings, rings.dropFirst()).allSatisfy { $0.radius > $1.radius && $0.color.alpha > $1.color.alpha })
            #expect(Self.shockwave.rings(at: .init(spread: 0.08)).count == 2)
        }
    }
#endif
