#if Graphics
    import Motion
    import Picture
    import Testing
    import Timeline

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
                glow: .init(deviation: 12, strength: 1)
            )
        )

        static func single(radius: Double = 20, travel: Timeline.Easing<Double> = .linear, glow: Motion.Graphics.Glow? = nil) -> Motion.Graphics.Shockwave {
            Motion.Graphics.Shockwave(
                at: Picture.Plane.Point<2>([300, 200]),
                style: .init(
                    radius: radius,
                    reach: 600,
                    travel: travel,
                    pen: 30,
                    least: 4,
                    color: .white,
                    finish: .white,
                    fall: 1,
                    trail: .init(count: 0, lag: 0, fade: 1),
                    glow: glow
                )
            )
        }

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

        @Test func `at spread 0 the wave is its starting ring at full light, a point of light from no radius`() throws {
            let start = try #require(Self.single().rings(at: .init(spread: 0)).first)
            #expect(start.radius == 20 && start.light == 1 && start.pen == 30)
            let point = Picture(Self.single(radius: 0), at: .init(spread: 0))
            guard case .layer(let layer) = point.elements.first, case .shape(let shape) = layer.content.elements.first else {
                Issue.record("a wave of no radius is a disc of light")
                return
            }
            #expect(shape.fill != nil && shape.stroke == nil)
            #expect(Picture(Self.single(), at: .hidden) == .empty)
        }

        @Test func `the wave lights a thing at a distance by the law its rings are drawn with`() {
            let wave = Self.single()
            let moment = Motion.Graphics.Shockwave.Moment(spread: 0.5)
            let ring = wave.rings(at: moment)[0]
            #expect(ring.radius == 320 && ring.light == 0.5)
            #expect(wave.light(at: 320, moment: moment) == 0.5)
            #expect(Swift.abs(wave.light(at: 320 + ring.pen / 2, moment: moment) - 0.25) < 1e-12)
            #expect(wave.light(at: 320 - ring.pen, moment: moment) == 0)
            #expect(wave.light(at: 0, moment: moment) == 0)
            #expect(wave.light(at: 320, moment: .resting) == 0)
            let trailed = Self.shockwave.rings(at: moment)
            #expect(Self.shockwave.light(at: trailed[1].radius, moment: moment) >= trailed[1].light)
        }

        @Test func `the reach follows its own easing while the pen and the light follow the spread`() {
            let eased = Self.single(travel: .power(4).reversed)
            let plain = Self.single()
            let (a, b) = (eased.rings(at: .init(spread: 0.3))[0], plain.rings(at: .init(spread: 0.3))[0])
            #expect(Swift.abs(a.radius - (20 + 600 * (1 - 0.7 * 0.7 * 0.7 * 0.7))) < 1e-9)
            #expect(a.pen == b.pen && a.light == b.light && a.color == b.color)
        }

        @Test func `with no glow the rings are drawn without one`() {
            let bare = Picture(Self.single(), at: .init(spread: 0.4))
            guard case .layer(let layer) = bare.elements.first else {
                Issue.record("rings add their light in a layer")
                return
            }
            #expect(layer.content.elements.count == 1)
            let glowing = Picture(Self.single(glow: .init(deviation: 8, strength: 1)), at: .init(spread: 0.4))
            guard case .layer(let lit) = glowing.elements.first else { return }
            #expect(lit.content.elements.count == 2)
        }
    }
#endif
