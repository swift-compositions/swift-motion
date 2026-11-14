#if Graphics
    import Motion
    import Picture
    import Testing

    @testable import Motion_Graphics

    @Suite struct `Marquee Tests` {
        typealias Tests = `Graphics Tests`

        static func marquee(_ font: ISO_14496_22.FontFile) throws -> Motion.Graphics.Marquee {
            try Motion.Graphics.Marquee(
                ["SHAPE TYPE COLOUR", "MOTION"],
                in: Picture.Plane.Rectangle(llx: 0, lly: 100, urx: 1200, ury: 600),
                style: .init(ink: Tests.ink(font, 120), faces: [.filled, .outlined(4)], pitch: 110, gap: 60)
            )
        }

        @Test func `rows fill the region a pitch apart`() throws {
            #expect(try Self.marquee(Fonts.sans).rows == 5)
        }

        @Test func `a row's offset wraps every unit, even rows sliding left and odd rows right`() throws {
            let marquee = try Self.marquee(Fonts.sans)
            for row in [0, 1, 2, 3] as [Ordinal] {
                let unit = marquee.unit(row: row)
                #expect(unit > 60)
                for travel in [0, 13.5, 250, 999.25, 4321] {
                    let offset = marquee.offset(row: row, travel: travel)
                    #expect(offset >= 0 && offset < unit)
                    for later in [travel + unit, travel + 3 * unit] {
                        let apart = Swift.abs(marquee.offset(row: row, travel: later) - offset)
                        #expect(Swift.min(apart, unit - apart) < 1e-6, "the offset wraps: a whole unit on is the same place")
                    }
                }
                let moved = marquee.offset(row: row, travel: 10)
                #expect(Swift.abs(moved - (Int(bitPattern: row) % 2 == 0 ? 10 : unit - 10)) < 1e-9)
            }
        }

        @Test func `a marquee hidden draws nothing, and its rows' copies cover the region, filled and outlined in turn`() throws {
            let marquee = try Self.marquee(Fonts.sans)
            #expect(Picture(marquee, at: .hidden) == .empty)
            #expect(Picture(marquee, at: .init(travel: 40, rows: [0, 0])) == .empty)
            let picture = Picture(marquee, at: .init(travel: 333, rows: [1, 1, 1, 1, 1]))
            #expect(picture.elements.count == 5)
            for (index, element) in picture.elements.enumerated() {
                guard case .group(let row) = element else {
                    Issue.record("a row is a clipped group")
                    continue
                }
                let starts = row.content.elements.compactMap { copy -> Double? in
                    guard case .group(let group) = copy else { return nil }
                    return group.transform.applied(to: Vector([0.0, 0.0]))[0]
                }
                let unit = marquee.unit(row: Ordinal(UInt(index)))
                #expect((starts.first ?? 1) <= 0)
                #expect((starts.last ?? 0) + unit >= 1200)
                guard case .group(let copy) = row.content.elements.first, case .shape(let shape) = copy.content.elements.first else {
                    Issue.record("a row's first copy is a shape in a group")
                    continue
                }
                #expect((shape.stroke == nil) == (index % 2 == 0))
            }
        }

        static func styled(_ font: ISO_14496_22.FontFile, rise: Double? = nil, slot: Motion.Graphics.Slot? = nil, starts: [Double] = []) throws -> Motion.Graphics.Marquee {
            try Motion.Graphics.Marquee(
                ["SHAPE TYPE COLOUR", "MOTION"],
                in: Picture.Plane.Rectangle(llx: 0, lly: 100, urx: 1200, ury: 600),
                style: .init(ink: Tests.ink(font, 120), faces: [.filled], pitch: 110, gap: 60, rise: rise, slot: slot, starts: starts)
            )
        }

        static func rows(_ picture: Picture) -> [(clip: Picture.Plane.Rectangle?, first: Picture.Transform?)] {
            picture.elements.map { element in
                guard case .group(let row) = element else { return (nil, nil) }
                var first: Picture.Transform?
                if case .group(let copy) = row.content.elements.first { first = copy.transform }
                return (row.clip.flatMap { $0.path.boundingBox }, first)
            }
        }

        @Test func `a row rises by the style's rise, through its slot about its resting baseline, from its own start`() throws {
            let cap = try Picture.Text.Metrics(font: Fonts.sans, size: 120).cap
            let resting = 100 + (110 + cap) / 2
            let plain = Self.rows(Picture(try Self.styled(Fonts.sans), at: .init(travel: 0, rows: [0.5])))
            #expect(Swift.abs((plain[0].first?[1, 2] ?? 0) - (resting + 55)) < 1e-9)
            #expect(plain[0].clip.map { $0.lly.underlying == 100 && $0.ury.underlying == 210 } == true)
            let risen = Self.rows(Picture(try Self.styled(Fonts.sans, rise: 120, slot: .init(above: 0.8, below: 0.1)), at: .init(travel: 0, rows: [0.5])))
            #expect(Swift.abs((risen[0].first?[1, 2] ?? 0) - (resting + 60)) < 1e-9)
            let clip = try #require(risen[0].clip)
            #expect(Swift.abs(clip.lly.underlying - Swift.max(resting - 96, 100)) < 1e-9 && Swift.abs(clip.ury.underlying - (resting + 12)) < 1e-9)
            let started = try Self.styled(Fonts.sans, starts: [0, 37])
            let unit = started.unit(row: 1)
            #expect(Swift.abs(started.offset(row: 1, travel: 10) - (unit - 47)) < 1e-9)
            #expect(started.offset(row: 0, travel: 10) == (try Self.marquee(Fonts.sans).offset(row: 0, travel: 10)))
            #expect(started.offset(row: 3, travel: 10) == (started.offset(row: 1, travel: 10)))
        }
    }
#endif
