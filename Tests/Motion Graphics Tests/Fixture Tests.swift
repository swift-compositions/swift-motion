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
                anchor: .center,
                style: .init(
                    transcript: Self.transcript,
                    plate: .init(surface: .fill(Picture.Color(gray: 0, alpha: 0.9)), corners: .circular(8)),
                    ascent: 16,
                    descent: 5,
                    horizontal: 16,
                    vertical: 12,
                    rise: 20
                )
            )
            drawn.append(("caption resting", Picture(caption, at: .resting)))
            drawn.append(("caption rising", Picture(caption, at: .init(shown: 0.5, risen: 0.4, line: .init(typed: 0.6, caret: 1)))))

            let headline = try Motion.Graphics.Headline(
                [.init("A CIRCLE."), .init("FOR NOW, AND LONGER", offset: 12)],
                at: Picture.Plane.Point<2>([500, 300]),
                region: Picture.Plane.Path(Picture.Plane.Rectangle(llx: 300, lly: 200, urx: 600, ury: 400)),
                style: .init(
                    ink: .init(font: sans, size: 400, color: .white),
                    second: .black,
                    measure: 640,
                    pitch: 0.9,
                    rise: 0.95,
                    slot: .init(above: 0.8, below: 0.1),
                    span: 1000
                )
            )
            drawn.append(("headline resting", Picture(headline, at: .init([.resting, .resting]))))
            drawn.append(("headline opening", Picture(headline, at: .init([.init(risen: 0.5), .hidden], opened: 0.3))))
            drawn.append(("headline leaving", Picture(headline, at: .init([.init(risen: 1, gone: 0.4), .init(risen: 0.8)]))))

            let title = try Motion.Graphics.Title(
                ["AB ", "CD"],
                at: Picture.Plane.Point<2>([600, 400]),
                anchor: .center,
                style: .init(
                    ink: .init(font: sans, size: 100, color: .white),
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
                    heading: .init(ink: Motion.Graphics.Ink(font: sans, size: 14, color: .white, tracking: 0.3), toned: Picture.Color(hex: 0xFF0000), slide: 20),
                    statement: .init(ink: ink(sans, 36), indent: -2, rise: 40, slot: .init(above: 32.0 / 36, below: 12.0 / 36)),
                    row: .init(box: box, rise: 8, name: ink(sans, 20), gap: 26, slide: 12, tag: ink(sans, 14, Picture.Color(hex: 0xFFFF00)), drop: -1),
                    plate: .init(
                        surface: .frosted(deviation: 12, coat: .clear),
                        corners: .continuous(16, exponent: 5),
                        edge: .init(color: .white, pen: 1.5),
                        coat: Picture.Gradient([.init(offset: 0, color: Picture.Color(gray: 0.1, alpha: 0.4)), .init(offset: 1, color: Picture.Color(gray: 0.1, alpha: 0.6))])
                    ),
                    settle: 0.07
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
                anchor: .trailing,
                style: .init(
                    ink: ink(sans, 24, Picture.Color(gray: 0.7)),
                    accent: [.white, Picture.Color(hex: 0xFF0000)],
                    finish: Picture.Color(hex: 0x0000FF),
                    plate: .init(surface: .fill(.black), corners: .circular(10), edge: .init(color: .white, pen: 2)),
                    height: 60,
                    inset: 16,
                    baseline: 34,
                    edge: 0.2,
                    flash: 0.5,
                    bar: .init(top: 44, height: 4, track: Picture.Color(gray: 0.3)),
                    glow: .init(deviation: 5, strength: 0.3, flash: 0.5),
                    heat: .init(edge: 0.5, glow: 0.5),
                    grow: 0.4,
                    fade: 3
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
                "~/film zsh",
                in: Picture.Plane.Rectangle(llx: 10, lly: 10, urx: 410, ury: 310),
                style: .init(
                    title: ink(sans, 14),
                    plate: .init(surface: .fill(Picture.Color(gray: 0.1)), corners: .continuous(14, exponent: 5), edge: .init(color: .white, pen: 2)),
                    bar: 30,
                    rule: .white,
                    line: 2,
                    lights: .init(count: 3, radius: 5, inset: 20, step: 16, color: Picture.Color(hex: 0xFF0000))
                )
            )
            drawn.append(("window resting", Picture(window, at: .resting)))
            drawn.append(("window fading", Picture(window, at: .init(shown: 0.5))))
            return drawn
        }

        static let recorded: [Swift.String: UInt64] = [
            "transcript resting": 1_640_226_509_578_681_109,
            "transcript typing": 18_289_386_924_219_359_063,
            "caption resting": 4_946_059_160_609_638_222,
            "caption rising": 12_710_238_585_639_767_663,
            "headline resting": 10_487_367_973_085_316_343,
            "headline opening": 15_519_934_907_906_524_253,
            "headline leaving": 16_253_555_918_541_238_107,
            "title resting": 5_292_016_915_539_695_405,
            "title entering": 16_489_143_591_555_582_332,
            "checkbox ticked": 2_784_461_774_130_099_648,
            "checkbox landing": 16_147_120_335_591_652_713,
            "checklist resting": 11_752_956_424_575_639_925,
            "checklist settling": 17_550_991_597_331_292_454,
            "checklist plate": 14_194_700_833_036_097_455,
            "row alone": 10_588_919_701_684_145_495,
            "readout resting": 15_482_293_470_861_662_027,
            "readout hot": 10_268_088_694_130_062_264,
            "spinner resting": 16_266_280_015_939_450_184,
            "spinner turning": 15_781_712_931_433_804_629,
            "shockwave thrown": 2_549_696_278_478_644_110,
            "shockwave spreading": 10_929_958_505_636_346_412,
            "shockwave late": 16_726_592_411_800_379_126,
            "marquee travelling": 1_070_553_715_433_432_354,
            "marquee rising": 9_729_252_672_618_603_130,
            "glint middle": 718_645_254_237_998_007,
            "glint dim": 5_448_604_862_037_740_409,
            "twinkle whole": 6_143_069_992_004_345_804,
            "twinkle early": 5_993_012_689_001_501_475,
            "window resting": 880_798_150_518_453_965,
            "window fading": 7_081_507_044_841_347_336,
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
