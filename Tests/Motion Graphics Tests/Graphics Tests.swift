#if Graphics
    import Motion
    import Picture
    import Testing
    import Timeline

    @testable import Motion_Graphics

    @Suite struct `Graphics Tests` {
        static func ink(_ font: ISO_14496_22.FontFile, _ size: Double, _ color: Picture.Color = .white) -> Motion.Graphics.Ink {
            Motion.Graphics.Ink(font: font, size: size, color: color)
        }

        static func transcript(_ font: ISO_14496_22.FontFile, columns: Cardinal? = nil) -> Motion.Graphics.Transcript.Style {
            Motion.Graphics.Transcript.Style(
                typed: ink(font, 20),
                said: ink(font, 20, Picture.Color(gray: 0.8)),
                mark: ink(font, 20, Picture.Color(hex: 0xFF0000)),
                leading: 32,
                caret: .init(color: Picture.Color(hex: 0xFF0000), left: 1, right: 1, top: 17, bottom: 5, radius: 1, deviation: 4, strength: 0.5),
                columns: columns
            )
        }

        static let glass = Picture.Glass(
            tint: Picture.Color(gray: 1, alpha: 0.1),
            refraction: .init(index: 1.5, distance: 10),
            frost: 4
        )

        static let glassy = Motion.Graphics.Surface.glass(glass, thickness: 12, rim: 14)

        /// The first pane anywhere in a picture, inside groups and layers.
        static func pane(in picture: Picture) -> Picture.Glass.Pane? {
            for element in picture.elements {
                switch element {
                case .pane(let pane): return pane
                case .group(let group): if let pane = pane(in: group.content) { return pane }
                case .layer(let layer): if let pane = pane(in: layer.content) { return pane }
                default: continue
                }
            }
            return nil
        }

        static func readout(_ font: ISO_14496_22.FontFile, surface: Motion.Graphics.Surface = .fill(.black)) throws -> Motion.Graphics.Readout {
            try Motion.Graphics.Readout(
                "FRAME",
                of: "/ ",
                total: 1650,
                at: Picture.Plane.Point<2>([400, 20]),
                anchor: .right,
                style: .init(
                    ink: ink(font, 24, Picture.Color(gray: 0.7)),
                    accent: [.white, Picture.Color(hex: 0xFF0000)],
                    finish: Picture.Color(hex: 0x0000FF),
                    plate: .init(surface: surface, corners: .circular(10), height: 60, inset: 16, baseline: 34, pen: 2, edge: 0.2, heat: 0.5, flash: 0.5),
                    bar: .init(top: 44, height: 4, track: Picture.Color(gray: 0.3)),
                    glow: .init(deviation: 5, rest: 0.3, heat: 0.5, flash: 0.5),
                    grow: 0.4,
                    fade: 3,
                    pivot: Picture.Plane.Point<2>([12, 10])
                )
            )
        }

        static func box() -> Motion.Graphics.Checkbox.Style {
            Motion.Graphics.Checkbox.Style(
                half: 12,
                radius: 4,
                pen: 2,
                edge: .white,
                fill: Picture.Color(hex: 0x00FF00),
                least: 0.1,
                glow: .init(deviation: 6, rest: 0.25, flash: 0.75),
                overshoot: 1.2,
                tick: [Picture.Plane.Point<2>([-6, 0]), Picture.Plane.Point<2>([-2, 5]), Picture.Plane.Point<2>([6, -5])],
                mark: .black,
                weight: 3
            )
        }

        static func checklist(_ font: ISO_14496_22.FontFile, surface: Motion.Graphics.Surface = .frosted(deviation: 12, coat: .clear)) throws -> Motion.Graphics.Checklist {
            try Motion.Graphics.Checklist(
                heading: "REQUIREMENTS",
                statement: "A film needs:",
                items: [.init("Shape", tag: "Bézier"), .init("Type", tag: "OpenType"), .init("Colour")],
                layout: .init(
                    left: 40,
                    right: 400,
                    heading: 60,
                    statement: 110,
                    first: 170,
                    pitch: 44,
                    plate: Picture.Plane.Rectangle(llx: 20, lly: 20, urx: 420, ury: 320)
                ),
                style: .init(
                    heading: .init(ink: ink(font, 14), tracking: 0.3, toned: Picture.Color(hex: 0xFF0000), slide: 20),
                    statement: .init(ink: ink(font, 36), indent: -2, rise: 40, above: 32, height: 44),
                    row: .init(box: box(), rise: 8, name: ink(font, 20), gap: 26, slide: 12, tag: ink(font, 14, Picture.Color(hex: 0xFFFF00)), drop: -1),
                    plate: .init(
                        surface: surface,
                        corners: .continuous(16, exponent: 5),
                        top: Picture.Color(gray: 0.1, alpha: 0.4),
                        foot: Picture.Color(gray: 0.1, alpha: 0.6),
                        edge: .white,
                        pen: 1.5,
                        settle: 0.07
                    )
                )
            )
        }

        @Test func `a share of a line's characters stands floor of the share times their count, and k over n stands k`() {
            let count = 49
            for k in 0...count {
                #expect(Motion.Graphics.standing(Double(k) / Double(count), of: count) == k)
            }
            for share in stride(from: 0.0001, to: 1, by: 0.0037) {
                let standing = Motion.Graphics.standing(share, of: count)
                #expect(Double(standing) / Double(count) <= share && Double(standing + 1) / Double(count) > share, "\(share)")
            }
            #expect(Motion.Graphics.standing(-0.5, of: count) == 0)
            #expect(Motion.Graphics.standing(1.5, of: count) == count)
        }

        @Test func `a typed line shows the glyphs its share stands, as the line of only those glyphs would`() throws {
            let text = "swift run film\nproceeding e\u{301}anyway."
            let origin = Picture.Plane.Point<2>([10, 40])
            let style = Self.transcript(Fonts.mono)
            let line = Motion.Graphics.Transcript.Line(.prompt(">"), text)
            let count = Int(clamping: line.length)
            #expect(count == 34)
            let set = try Motion.Graphics.Transcript([line], at: origin, style: style)
            let bytes = Swift.Array(text.utf8)
            for k in [0, 1, 7, 14, 15, 20, 27, 28, count] {
                let ends = bytes.indices.filter { bytes[$0] & 0xc0 != 0x80 } + [bytes.count]
                let prefix = ends.lazy.map { Swift.String(decoding: bytes[..<$0], as: UTF8.self) }.first { Picture.Text.length(of: $0) == k } ?? text
                let typed = Picture(set, at: .init([.init(typed: Double(k) / Double(count))]))
                let alone = Picture(try Motion.Graphics.Transcript([.init(.prompt(">"), prefix)], at: origin, style: style), at: .init([.resting]))
                #expect(typed == alone, "\(k) glyphs")
            }
        }

        @Test func `rows break at line feeds and before a word past the columns, a diagnostic's rows under its first word`() throws {
            let line = Motion.Graphics.Transcript.Line(.label("note:", Picture.Color(hex: 0x00FFFF)), "one two three\nfour")
            #expect(line.rows(within: nil).map(\.words) == ["one two three", "four"])
            #expect(line.rows(within: nil).map(\.start) == [0, 13])
            #expect(line.rows(within: 12).map(\.words) == ["one", "two", "three", "four"])
            #expect(line.rows(within: 12).map(\.start) == [0, 4, 8, 13])
            #expect(try Motion.Graphics.Transcript.Setting(line, style: Self.transcript(Fonts.mono)).columns == 6 + 13)
        }

        @Test func `typing strikes its first key at the start and its last at the end, at the weights' gaps`() throws {
            let start = try Rational(numerator: 1, denominator: 2)
            let end = try Rational(numerator: 3, denominator: 2)
            let typing = Motion.Graphics.Typing(4, from: start, to: end, weights: [Rational(1), Rational(2), Rational(1)])
            #expect(typing.strokes == [start, try Rational(numerator: 3, denominator: 4), try Rational(numerator: 5, denominator: 4), end])
            #expect(typing.standing(at: .zero) == 0)
            #expect(typing.standing(at: start) == 1)
            #expect(typing.standing(at: end) == 4)
            #expect(typing.share(at: try Rational(numerator: 4, denominator: 5)) == 0.5)
            let blink = try Rational(numerator: 1, denominator: 4)
            #expect(typing.lit(at: .zero, blink: blink))
            #expect(!typing.lit(at: try Rational(numerator: 3, denominator: 10), blink: blink))
            #expect(typing.lit(at: Rational(1), blink: blink))
            #expect(!typing.lit(at: end + blink, blink: blink))
        }

        @Test func `a headline's lines are set at the one size that fits the widest to the measure`() throws {
            let headline = try Motion.Graphics.Headline(
                [.init("A CIRCLE."), .init("FOR NOW, AND LONGER")],
                about: Picture.Plane.Point<2>([500, 300]),
                style: .init(font: Fonts.sans, size: 400, measure: 640, pitch: 0.9, rise: 0.95, slot: .init(above: 0.8, height: 0.9), span: 1000, ink: .white, second: .black)
            )
            let placed = headline.placements(at: .init([.resting, .resting]))
            #expect(placed.count == 2)
            #expect(placed.allSatisfy { $0.text.width <= 640 + 1e-6 })
            #expect(Swift.abs((placed.map(\.text.width).max() ?? 0) - 640) < 1e-6)
            #expect(Swift.abs(placed[1].point[1] - placed[0].point[1] - 0.9 * headline.size) < 1e-9)
            #expect(Picture(headline, at: .init([.hidden, .hidden])) == .empty)
            #expect(Picture(headline, at: .init([.init(risen: 1, gone: 1), .hidden])) == .empty)
        }

        @Test func `a checklist's rows sit on its layout's pitch, each box its rise above its row's baseline`() throws {
            let checklist = try Self.checklist(Fonts.sans)
            let rows = checklist.rows
            #expect(rows.map(\.baseline) == [170, 214, 258])
            #expect(rows.allSatisfy { $0.checkbox.centre == Picture.Plane.Point<2>([40 + 12, $0.baseline - 8]) })
            #expect(Picture(checklist, at: .hidden) == .empty)
            #expect(Picture(checklist, at: .resting(3)).elements.count == 2 + 1 + 1 + 3)
            #expect(Picture(checklist, at: .resting(3)) != Picture(checklist, at: .resting(2)))
        }

        @Test func `a box springs, fills and is ticked by its moment, and draws nothing hidden`() {
            let checkbox = Motion.Graphics.Checkbox(at: Picture.Plane.Point<2>([50, 50]), style: Self.box())
            #expect(Picture(checkbox, at: .hidden) == .empty)
            #expect(Picture(checkbox, at: .resting).elements.count == 1)
            #expect(Picture(checkbox, at: .ticked).elements.count == 4)
            #expect(Picture(checkbox, at: .init(box: 2)) == Picture(checkbox, at: .init(box: 1.2)))
        }

        @Test func `a readout's count has one advance, so its plate and its total stand still whatever it reads`() throws {
            let readout = try Self.readout(Fonts.sans)
            #expect(readout.figures(of: 66) == "0066")
            #expect(readout.figures(of: 1650) == "1650")
            #expect(readout.figures(of: 9999) == "1650")
            let plates = [0, 1, 7, 111, 1111, 1650, 9999].map { value in Picture(readout, at: .resting(Cardinal(UInt(value)))) }
                .map { picture -> Picture.Element? in
                    guard case .group(let placed) = picture.elements.first else { return nil }
                    return placed.content.elements.first
                }
            #expect(plates.allSatisfy { $0 != nil && $0 == plates[0] })
            #expect(Picture(readout, at: .hidden) == .empty)
            #expect(Picture(readout, at: .init(count: 3, light: 0)) == .empty)
        }

        @Test func `a readout's plate is the one its drawing lays, under the transform it is drawn in at a moment`() throws {
            let readout = try Self.readout(Fonts.sans)
            let plate = readout.plate
            #expect(plate.urx.underlying == 400 && plate.lly.underlying == 20 && plate.ury.underlying == 80)
            let style = readout.style.plate
            for moment in [Motion.Graphics.Readout.Moment.resting(66), .init(count: 1649, shown: 0.5), .init(count: 66, shown: 1.05, tilt: 0.2, drop: 12)] {
                let picture = Picture(readout, at: moment)
                let drawn = if case .layer(let layer) = picture.elements.first { layer.content } else { picture }
                guard case .group(let placed) = drawn.elements.first else {
                    Issue.record("a readout is drawn in one group")
                    continue
                }
                #expect(placed.transform == readout.transform(at: moment))
                #expect(Swift.Array(placed.content.elements.prefix(1)) == style.surface.elements(plate, corners: style.corners))
            }
            let middle = Picture.Plane.Point<2>([(plate.llx.underlying + plate.urx.underlying) / 2, 50])
            let still = readout.transform(at: .init(count: 66, shown: 0.5)).applied(to: Vector([middle[0], middle[1]]))
            #expect(Swift.abs(still[0] - middle[0]) < 1e-9 && Swift.abs(still[1] - middle[1]) < 1e-9)
        }

        @Test func `a readout's accent mixes its colours by heat, as written, then toward its finish`() throws {
            let style = try Self.readout(Fonts.sans).style
            #expect(style.lit(heat: 0, finished: 0) == .white)
            #expect(style.lit(heat: 1, finished: 0) == Picture.Color(hex: 0xFF0000))
            #expect(style.lit(heat: 0.5, finished: 0) == Picture.Color.white.mixed(inSRGBTo: Picture.Color(hex: 0xFF0000), at: 0.5))
            #expect(style.lit(heat: 0.5, finished: 1) == Picture.Color(hex: 0x0000FF))
        }

        @Test func `a caption's plate centres the whole line on its place, its last baseline through it`() throws {
            let caption = try Motion.Graphics.Caption(
                .init(.label("note:", Picture.Color(hex: 0x00FFFF)), "declared here"),
                at: Picture.Plane.Point<2>([500, 400]),
                style: .init(
                    transcript: Self.transcript(Fonts.mono),
                    plate: .init(surface: .fill(Picture.Color(gray: 0, alpha: 0.9)), corners: .circular(8), ascent: 16, descent: 5, horizontal: 16, vertical: 12),
                    rise: 20
                )
            )
            let plate = caption.plate
            let width = caption.transcript.width
            #expect(Swift.abs((plate.llx.underlying + plate.urx.underlying) / 2 - 500) < 1e-9)
            #expect(Swift.abs(plate.urx.underlying - plate.llx.underlying - width - 32) < 1e-9)
            #expect(plate.lly.underlying == 400 - 16 - 12)
            #expect(plate.ury.underlying == 400 + 5 + 12)
            #expect(Picture(caption, at: .hidden) == .empty)
            #expect(Picture(caption, at: .resting).elements.count == 3)
        }

        @Test func `a window's body stands under its bar, and a window hidden draws nothing`() throws {
            let window = try Motion.Graphics.Window(
                frame: Picture.Plane.Rectangle(llx: 10, lly: 10, urx: 410, ury: 310),
                title: "~/film — zsh",
                style: .init(
                    title: Self.ink(Fonts.sans, 14),
                    corners: .circular(12),
                    bar: 30,
                    line: 2,
                    edge: .white,
                    rule: .white,
                    surface: .fill(.clear),
                    lights: .init(count: 3, radius: 5, inset: 20, step: 16, color: Picture.Color(hex: 0xFF0000))
                )
            )
            #expect(window.body == Picture.Plane.Rectangle(llx: 10, lly: 42, urx: 410, ury: 310))
            #expect(Picture(window, at: .hidden) == .empty)
            #expect(Picture(window, at: .resting).elements.count == 6)
        }

        @Test func `corners give a plate's region and outline: circular, continuous and a capsule`() {
            let frame = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 200, ury: 60)
            #expect(Motion.Graphics.Corners.circular(12).region(frame) == .rectangle(frame, radius: 12))
            #expect(Motion.Graphics.Corners.capsule.region(frame) == .capsule(frame))
            #expect(Motion.Graphics.Corners.continuous(20, exponent: 5).region(frame) == .superellipse(.init(frame, radius: 20, exponent: 5)))
            #expect(Motion.Graphics.Corners.circular(12).path(frame) == Picture.Plane.Path(frame, radius: 12))
            #expect(Motion.Graphics.Corners.capsule.path(frame) == Picture.Plane.Path(frame, radius: 30))
            let region = Motion.Graphics.Corners.continuous(20, exponent: 5).region(frame)
            for segment in Motion.Graphics.Corners.continuous(20, exponent: 5).path(frame).subpaths[0].segments {
                guard let start = segment.startPoint else { continue }
                #expect(Swift.abs(region.distance(to: start)) < 1e-9)
            }
        }

        @Test func `a surface is a fill of the outline, or a pane over the region: frosted, a glass without a body`() {
            let frame = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 200, ury: 60)
            let corners = Motion.Graphics.Corners.continuous(20, exponent: 5)
            #expect(Motion.Graphics.Surface.fill(.white).elements(frame, corners: corners) == [.fill(corners.path(frame), .solid(.white))])
            #expect(Motion.Graphics.Surface.fill(.clear).elements(frame, corners: corners).isEmpty)
            let coat = Picture.Color(gray: 0, alpha: 0.3)
            #expect(
                Motion.Graphics.Surface.frosted(deviation: 8, coat: coat).elements(frame, corners: corners)
                    == [.pane(Picture.Glass.Pane(corners.region(frame), glass: Picture.Glass(tint: coat, frost: 8), thickness: 0, rim: 0))]
            )
            #expect(
                Self.glassy.elements(frame, corners: corners)
                    == [.pane(Picture.Glass.Pane(corners.region(frame), glass: Self.glass, thickness: 12, rim: 14))]
            )
        }

        @Test func `a checklist's plate of glass is a pane over the grown plate, faded with the coat as it shows`() throws {
            let checklist = try Self.checklist(Fonts.sans, surface: Self.glassy)
            let rest = try #require(Self.pane(in: Picture(checklist, at: .resting(3))))
            #expect(rest.glass == Self.glass && rest.thickness == 12 && rest.rim == 14)
            #expect(rest.region == .superellipse(.init(Picture.Plane.Rectangle(llx: 20, lly: 20, urx: 420, ury: 320), radius: 16, exponent: 5)))
            var showing = Motion.Graphics.Checklist.Moment.resting(3)
            showing.shown = 0.5
            let half = Picture(checklist, at: showing)
            guard case .layer(let layer) = half.elements.first else {
                Issue.record("the plate fades in a layer")
                return
            }
            #expect(layer.opacity == 0.5)
            #expect(Self.pane(in: layer.content) == rest)
        }

        @Test func `a readout's plate of glass is a pane over the plate, inside its turn and growth`() throws {
            let readout = try Self.readout(Fonts.sans, surface: Self.glassy)
            let pane = try #require(Self.pane(in: Picture(readout, at: .resting(66))))
            #expect(pane.glass == Self.glass)
            guard case .rectangle(let frame, let radius) = pane.region else {
                Issue.record("circular corners make a rounded rectangle")
                return
            }
            #expect(radius == 10 && frame.urx.underlying == 400 && frame.lly.underlying == 20 && frame.ury.underlying == 80)
        }

        @Test func `a caption's plate of glass is a pane over its plate with its corners`() throws {
            let caption = try Motion.Graphics.Caption(
                .init(.label("note:", Picture.Color(hex: 0x00FFFF)), "declared here"),
                at: Picture.Plane.Point<2>([500, 400]),
                style: .init(
                    transcript: Self.transcript(Fonts.mono),
                    plate: .init(surface: Self.glassy, corners: .capsule, ascent: 16, descent: 5, horizontal: 16, vertical: 12),
                    rise: 20
                )
            )
            let pane = try #require(Self.pane(in: Picture(caption, at: .resting)))
            #expect(pane.region == .capsule(caption.plate))
            #expect(pane.glass == Self.glass)
        }

        @Test func `a window's body of glass is a pane over its frame with its corners`() throws {
            let frame = Picture.Plane.Rectangle(llx: 10, lly: 10, urx: 410, ury: 310)
            let window = try Motion.Graphics.Window(
                frame: frame,
                title: "~/film — zsh",
                style: .init(
                    title: Self.ink(Fonts.sans, 14),
                    corners: .continuous(14, exponent: 5),
                    bar: 30,
                    line: 2,
                    edge: .white,
                    rule: .white,
                    surface: Self.glassy,
                    lights: .init(count: 3, radius: 5, inset: 20, step: 16, color: Picture.Color(hex: 0xFF0000))
                )
            )
            let pane = try #require(Self.pane(in: Picture(window, at: .resting)))
            #expect(pane.region == .superellipse(.init(frame, radius: 14, exponent: 5)))
        }
    }
#endif
