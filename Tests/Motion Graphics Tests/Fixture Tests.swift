#if Graphics
    import Motion
    import Picture
    import Standard_Library_Extensions
    import Testing
    import Timeline

    @testable import Motion_Graphics

    /// Each component drawn at a few moments in the in-memory fonts, held to a digest of the picture's canonical
    /// bytes recorded from the drawing before the components were reworked: FNV-1a of `Swift.Mirror.bytes(of:)`.
    @Suite struct `Fixture Tests` {
        static func digest(_ picture: Picture) -> UInt64 {
            guard let bytes = Swift.Mirror.bytes(of: picture) else { return 0 }
            return bytes.reduce(0xcbf2_9ce4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
        }

        static let sans = Fonts.sans
        static let mono = Fonts.mono

        static func ink(_ font: ISO_14496_22.FontFile, _ size: Double, _ color: Picture.Color = .white) -> Motion.Graphics.Ink {
            Motion.Graphics.Ink(font: font, size: size, color: color)
        }

        static let transcript = Motion.Graphics.Transcript.Style(
            typed: ink(mono, 20),
            said: ink(mono, 20, Picture.Color(gray: 0.8)),
            mark: ink(mono, 20, Picture.Color(hex: 0xFF0000)),
            leading: 32,
            caret: .init(color: Picture.Color(hex: 0xFF0000), left: 1, right: 1, top: 17, bottom: 5, radius: 1, glow: .init(deviation: 4, strength: 0.5)),
            columns: 16
        )

        static func pictures() throws -> [(Swift.String, Picture)] {
            var drawn: [(Swift.String, Picture)] = []
            let lines: [Motion.Graphics.Transcript.Line] = [
                .init(.prompt(">"), "swift run film"),
                .init(.label("error:", Picture.Color(hex: 0x00FFFF)), "no such file here\nsecond row"),
                .init(.plain, "done"),
            ]
            let transcript = try Motion.Graphics.Transcript(lines, at: Picture.Plane.Point<2>([10, 40]), style: Self.transcript)
            drawn.append(("transcript resting", Picture(transcript, at: .init([.resting, .resting, .resting]))))
            drawn.append(("transcript typing", Picture(transcript, at: .init([.resting, .init(shown: 0.7, marked: 0.5, typed: 0.6, caret: 1)]))))

            let caption = try Motion.Graphics.Caption(
                .init(.label("note:", Picture.Color(hex: 0x00FFFF)), "declared here"),
                at: Picture.Plane.Point<2>([500, 400]),
                style: .init(
                    transcript: Self.transcript,
                    plate: .init(surface: .fill(Picture.Color(gray: 0, alpha: 0.9)), corners: .circular(8), ascent: 16, descent: 5, horizontal: 16, vertical: 12),
                    rise: 20
                )
            )
            drawn.append(("caption resting", Picture(caption, at: .resting)))
            drawn.append(("caption rising", Picture(caption, at: .init(shown: 0.5, risen: 0.4, line: .init(typed: 0.6, caret: 1)))))

            let headline = try Motion.Graphics.Headline(
                [.init("A CIRCLE."), .init("FOR NOW, AND LONGER", offset: 12)],
                about: Picture.Plane.Point<2>([500, 300]),
                region: Picture.Plane.Path(Picture.Plane.Rectangle(llx: 300, lly: 200, urx: 600, ury: 400)),
                style: .init(font: sans, size: 400, measure: 640, pitch: 0.9, rise: 0.95, slot: .init(above: 0.8, height: 0.9), span: 1000, ink: .white, second: .black)
            )
            drawn.append(("headline resting", Picture(headline, at: .init([.resting, .resting]))))
            drawn.append(("headline opening", Picture(headline, at: .init([.init(risen: 0.5), .hidden], opened: 0.3))))
            drawn.append(("headline leaving", Picture(headline, at: .init([.init(risen: 1, gone: 0.4), .init(risen: 0.8)]))))

            let title = try Motion.Graphics.Title(
                ["AB ", "CD"],
                at: Picture.Plane.Point<2>([600, 400]),
                anchor: .center,
                style: .init(
                    font: sans,
                    size: 100,
                    runs: [
                        .init(color: Picture.Color(hex: 0xFF0000), rise: 0.42, grow: 0, fade: 1.8),
                        .init(color: Picture.Color(hex: 0x0000FF), rise: -0.5, grow: 1.9, fade: 1.2, floor: 0.2),
                    ]
                )
            )
            drawn.append(("title resting", Picture(title, at: .resting(5))))
            drawn.append(("title entering", Picture(title, at: .init([0.5, 1.2, 0.1, 0, 1]))))

            let box = Motion.Graphics.Checkbox.Style(
                half: 12,
                radius: 4,
                pen: 2,
                edge: .white,
                fill: Picture.Color(hex: 0x00FF00),
                least: 0.1,
                glow: .init(deviation: 6, strength: 0.25, flash: 0.75),
                overshoot: 1.2,
                tick: [Picture.Plane.Point<2>([-6, 0]), Picture.Plane.Point<2>([-2, 5]), Picture.Plane.Point<2>([6, -5])],
                mark: .black,
                weight: 3
            )
            let checkbox = Motion.Graphics.Checkbox(at: Picture.Plane.Point<2>([50, 50]), style: box)
            drawn.append(("checkbox ticked", Picture(checkbox, at: .ticked)))
            drawn.append(("checkbox landing", Picture(checkbox, at: .init(box: 1.1, filled: 0.6, stroke: 0.5, flash: 0.7))))

            let checklist = try Motion.Graphics.Checklist(
                heading: "REQUIREMENTS",
                statement: "A film needs:",
                items: [.init("Shape", tag: "Bezier"), .init("Type", tag: "OpenType"), .init("Colour")],
                layout: .init(left: 40, right: 400, heading: 60, statement: 110, first: 170, pitch: 44, plate: Picture.Plane.Rectangle(llx: 20, lly: 20, urx: 420, ury: 320)),
                style: .init(
                    heading: .init(ink: ink(sans, 14), tracking: 0.3, toned: Picture.Color(hex: 0xFF0000), slide: 20),
                    statement: .init(ink: ink(sans, 36), indent: -2, rise: 40, above: 32, height: 44),
                    row: .init(box: box, rise: 8, name: ink(sans, 20), gap: 26, slide: 12, tag: ink(sans, 14, Picture.Color(hex: 0xFFFF00)), drop: -1),
                    plate: .init(
                        surface: .frosted(deviation: 12, coat: .clear),
                        corners: .continuous(16, exponent: 5),
                        top: Picture.Color(gray: 0.1, alpha: 0.4),
                        foot: Picture.Color(gray: 0.1, alpha: 0.6),
                        edge: .white,
                        pen: 1.5,
                        settle: 0.07
                    )
                )
            )
            drawn.append(("checklist resting", Picture(checklist, at: .resting(3))))
            drawn.append(
                (
                    "checklist settling",
                    Picture(
                        checklist,
                        at: .init(shown: 1, settled: 1, headed: 0.4, toned: 0.3, stated: 0.7, rows: [.resting, .init(box: .init(box: 1, filled: 1, stroke: 0.4), named: 0.5, tagged: 0.5)])
                    )
                )
            )
            drawn.append(("checklist plate", Picture(checklist, at: .init(shown: 0.6, settled: 1, headed: 0, toned: 0, stated: 0, rows: []))))
            drawn.append(("row alone", Picture(checklist.rows[1], at: .init(box: .ticked, named: 0.6, tagged: 0.5))))

            let readout = try Motion.Graphics.Readout(
                "FRAME",
                of: "/ ",
                total: 1650,
                at: Picture.Plane.Point<2>([400, 20]),
                anchor: .right,
                style: .init(
                    ink: ink(sans, 24, Picture.Color(gray: 0.7)),
                    accent: [.white, Picture.Color(hex: 0xFF0000)],
                    finish: Picture.Color(hex: 0x0000FF),
                    plate: .init(surface: .fill(.black), corners: .circular(10), height: 60, inset: 16, baseline: 34, pen: 2, edge: 0.2, flash: 0.5),
                    bar: .init(top: 44, height: 4, track: Picture.Color(gray: 0.3)),
                    glow: .init(deviation: 5, strength: 0.3, flash: 0.5),
                    heat: .init(edge: 0.5, glow: 0.5),
                    grow: 0.4,
                    fade: 3,
                    pivot: Picture.Plane.Point<2>([12, 10])
                )
            )
            drawn.append(("readout resting", Picture(readout, at: .resting(66))))
            drawn.append(("readout hot", Picture(readout, at: .init(count: 66, shown: 0.6, heat: 0.4, finished: 0.2, flash: 0.5, light: 0.8))))

            let spinner = Motion.Graphics.Spinner(
                at: Picture.Plane.Point<2>([100, 80]),
                radius: 40,
                style: .init(
                    pen: 8,
                    track: .init(color: Picture.Color(gray: 1, alpha: 0.2)),
                    arc: .init(color: Picture.Color(hex: 0xFF8800), glow: .init(deviation: 6, strength: 0.4, flash: 0.6))
                )
            )
            drawn.append(("spinner resting", Picture(spinner, at: .resting)))
            drawn.append(("spinner turning", Picture(spinner, at: .init(shown: 0.7, turn: 0.3, filled: 0.4, flash: 0.5))))

            let shockwave = Motion.Graphics.Shockwave(
                at: Picture.Plane.Point<2>([300, 200]),
                style: .init(
                    radius: 20,
                    reach: 600,
                    pen: 30,
                    least: 4,
                    color: .white,
                    finish: Picture.Color(hex: 0xB9F8DA),
                    fall: .power(2),
                    trail: .init(count: 3, lag: 0.06, fade: 0.6),
                    glow: .init(deviation: 12, strength: 1)
                )
            )
            drawn.append(("shockwave thrown", Picture(shockwave, at: .init(spread: 0))))
            drawn.append(("shockwave spreading", Picture(shockwave, at: .init(spread: 0.3))))
            drawn.append(("shockwave late", Picture(shockwave, at: .init(spread: 0.7))))

            let marquee = try Motion.Graphics.Marquee(
                ["SHAPE TYPE COLOUR", "MOTION"],
                in: Picture.Plane.Rectangle(llx: 0, lly: 100, urx: 1200, ury: 600),
                style: .init(ink: ink(sans, 120), faces: [.filled, .outlined(4)], pitch: 110, gap: 60, rise: 120, slot: .init(above: 0.8, below: 0.1), starts: [0, 37])
            )
            drawn.append(("marquee travelling", Picture(marquee, at: .init(travel: 333, rows: [1, 1, 1, 1, 1]))))
            drawn.append(("marquee rising", Picture(marquee, at: .init(travel: 50, rows: [0.5, 1, 0.2]))))

            let glint = Motion.Graphics.Glint(
                over: Picture.Plane.Path(Picture.Plane.Rectangle(llx: 100, lly: 50, urx: 500, ury: 150)),
                style: .init(color: .white, strength: 0.85, width: 160, slant: 0.4, glow: .init(deviation: 10, strength: 0.8))
            )
            drawn.append(("glint middle", Picture(glint, at: .init(swept: 0.5))))
            drawn.append(("glint dim", Picture(glint, at: .init(swept: 0.3, light: 0.6))))

            let twinkle = Motion.Graphics.Twinkle(
                at: Picture.Plane.Point<2>([200, 200]),
                style: .init(
                    rays: [.init(angle: 0, length: 120, width: 3), .init(angle: Double.pi / 4, length: 38, width: 3)],
                    color: .white,
                    core: Picture.Color(hex: 0xFFC060),
                    base: 4,
                    radius: 50,
                    turn: 0.6
                )
            )
            drawn.append(("twinkle whole", Picture(twinkle, at: .init(shone: 0.5))))
            drawn.append(("twinkle early", Picture(twinkle, at: .init(shone: 0.2))))

            let window = try Motion.Graphics.Window(
                frame: Picture.Plane.Rectangle(llx: 10, lly: 10, urx: 410, ury: 310),
                title: "~/film zsh",
                style: .init(
                    title: ink(sans, 14),
                    corners: .continuous(14, exponent: 5),
                    bar: 30,
                    line: 2,
                    edge: .white,
                    rule: .white,
                    surface: .fill(Picture.Color(gray: 0.1)),
                    lights: .init(count: 3, radius: 5, inset: 20, step: 16, color: Picture.Color(hex: 0xFF0000))
                )
            )
            drawn.append(("window resting", Picture(window, at: .resting)))
            drawn.append(("window fading", Picture(window, at: .init(shown: 0.5))))
            return drawn
        }

        static let recorded: [Swift.String: UInt64] = [
            "transcript resting": 1_919_760_481_970_589_639,
            "transcript typing": 11_523_613_729_735_406_970,
            "caption resting": 8_429_288_844_122_138_288,
            "caption rising": 8_863_960_655_988_885_005,
            "headline resting": 15_828_366_711_042_191_950,
            "headline opening": 7_580_291_359_931_506_163,
            "headline leaving": 15_250_019_066_242_027_754,
            "title resting": 12_822_106_672_574_920_797,
            "title entering": 6_324_645_190_859_423_714,
            "checkbox ticked": 4_054_222_210_072_137_773,
            "checkbox landing": 15_721_711_492_491_461_991,
            "checklist resting": 4_928_820_507_560_810_073,
            "checklist settling": 6_693_876_776_337_783_748,
            "checklist plate": 12_417_106_206_488_176_875,
            "row alone": 11_912_487_948_997_202_091,
            "readout resting": 1_622_257_752_498_448_375,
            "readout hot": 17_624_206_923_849_450_172,
            "spinner resting": 15_722_627_935_968_664_532,
            "spinner turning": 9_536_805_180_807_334_502,
            "shockwave thrown": 1_887_592_213_302_261_793,
            "shockwave spreading": 17_792_535_308_157_161_699,
            "shockwave late": 8_431_779_107_115_395_295,
            "marquee travelling": 12_688_707_738_795_288_682,
            "marquee rising": 10_248_491_775_882_240_363,
            "glint middle": 12_905_211_751_768_423_078,
            "glint dim": 6_613_518_248_332_825_968,
            "twinkle whole": 15_535_941_851_742_026_172,
            "twinkle early": 8_873_414_907_332_832_819,
            "window resting": 17_240_529_586_727_784_075,
            "window fading": 12_809_553_089_827_188_103,
        ]

        @Test func `each component draws the picture recorded for it`() throws {
            for (name, picture) in try Self.pictures() {
                let digest = Self.digest(picture)
                #expect(digest != 0, "\(name) is written whole")
                #expect(Self.recorded[name] == digest, "\(name): \(digest)")
            }
        }
    }
#endif
