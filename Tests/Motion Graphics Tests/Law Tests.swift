#if Graphics
    import Motion
    import Picture
    import Testing

    @testable import Motion_Graphics

    /// Laws the README states of the components that no other test held.
    @Suite struct `Law Tests` {
        typealias Tests = `Graphics Tests`

        /// Every shape anywhere in a picture, inside groups and layers.
        static func shapes(_ picture: Picture) -> [Picture.Shape] {
            picture.elements.flatMap { element -> [Picture.Shape] in
                switch element {
                case .shape(let shape): [shape]
                case .group(let group): shapes(group.content)
                case .layer(let layer): shapes(layer.content)
                default: []
                }
            }
        }

        @Test func `the caret stands in the cell after the last standing glyph, on the row the next one goes to`() throws {
            let style = Tests.transcript(Fonts.mono, columns: 10)
            let transcript = try Motion.Graphics.Transcript([.init(.prompt(">"), "one two three")], at: Picture.Plane.Point<2>([10, 40]), style: style)
            let advance = transcript.advance
            #expect(advance == 12)
            let count = 13
            for (k, row, cell) in [(0, 0, 0), (2, 0, 2), (5, 0, 5), (8, 1, 0), (13, 1, 5)] {
                let picture = Picture(transcript, at: .init([.init(typed: Double(k) / Double(count), caret: 1)]))
                let caret = try #require(Self.shapes(picture).last { $0.fill == .init(.solid(style.caret.color)) })
                let box = try #require(caret.path.boundingBox)
                #expect(box.llx.underlying == 10 + Double(2 + cell) * advance + style.caret.left, "\(k)")
                #expect(box.ury.underlying == 40 + Double(row) * style.leading + style.caret.bottom, "\(k)")
            }
        }

        @Test func `as a headline opens its first line goes from alone, capitals centered, to its place in the block`() throws {
            let headline = try Motion.Graphics.Headline(
                [.init("ONE"), .init("TWO")],
                at: Picture.Plane.Point<2>([500, 300]),
                region: Picture.Plane.Path(Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 500, ury: 600)),
                style: .init(
                    ink: .init(font: Fonts.sans, size: 100, color: .white),
                    second: .black,
                    measure: 10_000,
                    pitch: 1.2,
                    rise: 1,
                    slot: .init(above: 1, below: 0.3),
                    span: 1000
                )
            )
            let cap = 70.0
            let alone = headline.placements(at: .init([.resting], opened: 0))
            #expect(Swift.abs(alone[0].point[1] - (300 + cap / 2)) < 1e-9)
            let open = headline.placements(at: .resting(2))
            #expect(Swift.abs(open[0].point[1] - (300 + (cap - 120) / 2)) < 1e-9)
            #expect(Swift.abs(open[1].point[1] - open[0].point[1] - 120) < 1e-9)
            let half = headline.placements(at: .init([.resting], opened: 0.5))
            #expect(Swift.abs(half[0].point[1] - (alone[0].point[1] + open[0].point[1]) / 2) < 1e-9)
            guard case .group(let line) = Picture(headline, at: .resting(1)).elements.first,
                case .group(let inked) = line.content.elements.last
            else {
                Issue.record("a line is a slotted group, its second ink a group clipped to the region")
                return
            }
            #expect(inked.clip == Picture.Clip(Picture.Plane.Path(Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 500, ury: 600))))
            #expect(Self.shapes(inked.content).first?.fill == .init(.solid(.black)))
        }

        @Test func `a checklist's heading slides in from its slide and tones, and its statement rises inside its slot`() throws {
            let checklist = try Tests.checklist(Fonts.sans)
            let style = checklist.style
            var moment = Motion.Graphics.Checklist.Moment.hidden
            moment.headed = 0.5
            moment.toned = 1
            guard case .layer(let heading) = Picture(checklist, at: moment).elements.first,
                case .group(let placed) = heading.content.elements.first
            else {
                Issue.record("a heading sliding in is a layer")
                return
            }
            #expect(heading.opacity == 0.5)
            #expect(placed.transform.applied(to: Vector([0.0, 0.0]))[0] == 40 - 0.5 * style.heading.slide)
            #expect(Self.shapes(placed.content).first?.fill == .init(.solid(style.heading.ink.color.interpolated(inSRGBTo: style.heading.toned, at: 1))))
            moment = .hidden
            moment.stated = 0.25
            guard case .group(let statement) = Picture(checklist, at: moment).elements.first, case .group(let text) = statement.content.elements.first else {
                Issue.record("a statement is a group clipped to its slot")
                return
            }
            #expect(text.transform.applied(to: Vector([0.0, 0.0]))[1] == 110 + 0.75 * style.statement.rise)
            let slot = try #require(statement.clip?.path.boundingBox)
            let (top, bottom) = style.statement.slot.span(baseline: 110, size: 36)
            #expect(slot.lly.underlying == top && slot.ury.underlying == bottom && slot.llx.underlying == 20 && slot.urx.underlying == 420)
        }

        @Test func `a box's fill grows from its middle but never under its least half`() throws {
            let style = Tests.box()
            let checkbox = Motion.Graphics.Checkbox(at: Picture.Plane.Point<2>([50, 50]), style: style)
            for (filled, half) in [(0.005, 0.1), (0.01, 0.12), (0.5, 6.0), (1, 12.0)] {
                let picture = Picture(checkbox, at: .init(box: 1, filled: filled))
                let fill = try #require(Self.shapes(picture).first { $0.fill == .init(.solid(style.fill)) })
                let box = try #require(fill.path.boundingBox)
                #expect(Swift.abs((box.urx.underlying - box.llx.underlying) / 2 - half) < 1e-9, "\(filled)")
            }
        }

        @Test func `a caption rises from its rise below its place as it rises`() throws {
            let caption = try Motion.Graphics.Caption(
                .init(.plain, "declared"),
                at: Picture.Plane.Point<2>([500, 400]),
                anchor: .left,
                style: .init(
                    transcript: Tests.transcript(Fonts.mono),
                    plate: .init(surface: .fill(.black), corners: .circular(8)),
                    ascent: 16,
                    descent: 5,
                    horizontal: 16,
                    vertical: 12,
                    rise: 20
                )
            )
            #expect(caption.plate.llx.underlying == 500 - 16)
            guard case .group(let lowered) = Picture(caption, at: .init(shown: 1, risen: 0.25)).elements.first else {
                Issue.record("a caption not yet risen is lowered in a group")
                return
            }
            #expect(lowered.transform == .translation(x: 0, y: 15))
            #expect(lowered.content == Picture(caption, at: .resting))
        }
    }
#endif
