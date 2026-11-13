#if Graphics
    import Foundation
    import Motion
    import Picture
    import Testing
    import Timeline

    @testable import Motion_Graphics

    @Suite struct `Graphics Tests` {
        static let mono = font("/System/Library/Fonts/Supplemental/Andale Mono.ttf")
        static let sans = font("/System/Library/Fonts/Supplemental/Arial.ttf")

        static func font(_ path: Swift.String) -> ISO_14496_22.FontFile? {
            guard let data = FileManager.default.contents(atPath: path) else { return nil }
            do throws(ISO_14496_22.FontFile.ParsingError) {
                return try ISO_14496_22.FontFile(data: [Byte](bitPatterns: [UInt8](data)))
            } catch {
                return nil
            }
        }

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

        static func readout(_ font: ISO_14496_22.FontFile, value: Cardinal) -> Motion.Graphics.Readout {
            Motion.Graphics.Readout(
                "FRAME",
                value: value,
                of: "/ ",
                total: 1650,
                at: Picture.Plane.Point<2>([400, 20]),
                anchor: .right,
                style: .init(
                    ink: ink(font, 24, Picture.Color(gray: 0.7)),
                    accent: [.white, Picture.Color(hex: 0xFF0000)],
                    finish: Picture.Color(hex: 0x0000FF),
                    plate: .init(color: .black, height: 60, radius: 10, inset: 16, baseline: 34, pen: 2, edge: 0.2, heat: 0.5, flash: 0.5),
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

        static func checklist(_ font: ISO_14496_22.FontFile) -> Motion.Graphics.Checklist {
            Motion.Graphics.Checklist(
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
                    plate: .init(radius: 16, blur: 12, top: Picture.Color(gray: 0.1, alpha: 0.4), foot: Picture.Color(gray: 0.1, alpha: 0.6), edge: .white, pen: 1.5, settle: 0.07)
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

        @Test func `a typed line shows the characters its share stands, as the line of only those characters would`() throws {
            guard let mono = Self.mono else { return }
            let text = "swift run film\nproceeding anyway."
            let origin = Picture.Plane.Point<2>([10, 40])
            let style = Self.transcript(mono)
            for k in [0, 1, 7, 14, 15, 20, text.count] {
                let share = Double(k) / Double(text.count)
                let typed = try Picture(
                    Motion.Graphics.Transcript([.init(.prompt(">"), text)], at: origin, style: style),
                    at: .init([.init(typed: share)])
                )
                let alone = try Picture(
                    Motion.Graphics.Transcript([.init(.prompt(">"), Swift.String(text.prefix(k)))], at: origin, style: style),
                    at: .init([.resting])
                )
                #expect(typed == alone, "\(k) characters")
            }
        }

        @Test func `rows break at line feeds and before a word past the columns, a diagnostic's rows under its first word`() {
            let line = Motion.Graphics.Transcript.Line(.label("note:", Picture.Color(hex: 0x00FFFF)), "one two three\nfour")
            #expect(line.rows(within: nil).map { Swift.String($0.text) } == ["one two three", "four"])
            #expect(line.rows(within: nil).map(\.start) == [0, 14])
            #expect(line.rows(within: 12).map { Swift.String($0.text) } == ["one", "two", "three", "four"])
            #expect(line.rows(within: 12).map(\.start) == [0, 4, 8, 14])
            #expect(line.columns(within: nil) == 6 + 13)
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
            guard let sans = Self.sans else { return }
            let headline = Motion.Graphics.Headline(
                [.init("A CIRCLE."), .init("FOR NOW, AND LONGER")],
                about: Picture.Plane.Point<2>([500, 300]),
                style: .init(font: sans, size: 400, measure: 640, pitch: 0.9, rise: 0.95, slot: .init(above: 0.8, height: 0.9), span: 1000, ink: .white, second: .black)
            )
            let placed = try headline.placements(at: .init([.resting, .resting]))
            #expect(placed.count == 2)
            #expect(placed.allSatisfy { $0.text.width <= 640 + 1e-6 })
            #expect(Swift.abs((placed.map(\.text.width).max() ?? 0) - 640) < 1e-6)
            #expect(Swift.abs(placed[1].point[1] - placed[0].point[1] - 0.9 * (try headline.size)) < 1e-9)
            #expect(try Picture(headline, at: .init([.hidden, .hidden])) == .empty)
            #expect(try Picture(headline, at: .init([.init(risen: 1, gone: 1), .hidden])) == .empty)
        }

        @Test func `a checklist's rows sit on its layout's pitch, each box its rise above its row's baseline`() throws {
            guard let sans = Self.sans else { return }
            let checklist = Self.checklist(sans)
            let rows = checklist.rows
            #expect(rows.map(\.baseline) == [170, 214, 258])
            #expect(rows.allSatisfy { $0.checkbox.centre == Picture.Plane.Point<2>([40 + 12, $0.baseline - 8]) })
            #expect(try Picture(checklist, at: .hidden) == .empty)
            #expect(try Picture(checklist, at: .resting(3)).elements.count == 1 + 1 + 1 + 3)
            #expect(try Picture(checklist, at: .resting(3)) != Picture(checklist, at: .resting(2)))
        }

        @Test func `a box springs, fills and is ticked by its moment, and draws nothing hidden`() {
            let checkbox = Motion.Graphics.Checkbox(at: Picture.Plane.Point<2>([50, 50]), style: Self.box())
            #expect(Picture(checkbox, at: .hidden) == .empty)
            #expect(Picture(checkbox, at: .resting).elements.count == 1)
            #expect(Picture(checkbox, at: .ticked).elements.count == 1 + 2 + 1)
            #expect(Picture(checkbox, at: .init(box: 2)) == Picture(checkbox, at: .init(box: 1.2)))
        }

        @Test func `a readout's count has one advance, so its plate and its total stand still whatever it reads`() throws {
            guard let sans = Self.sans else { return }
            #expect(Self.readout(sans, value: 66).figures == "0066")
            #expect(Self.readout(sans, value: 1650).figures == "1650")
            let plates = try [0, 1, 7, 111, 1111, 1650, 9999].map { value in try Picture(Self.readout(sans, value: Cardinal(UInt(value))), at: .resting) }
                .map { picture -> Picture.Element? in
                    guard case .group(let turned) = picture.elements.first, case .group(let grown) = turned.content.elements.first else { return nil }
                    return grown.content.elements.first
                }
            #expect(plates.allSatisfy { $0 != nil && $0 == plates[0] })
            #expect(try Picture(Self.readout(sans, value: 3), at: .hidden) == .empty)
            #expect(try Picture(Self.readout(sans, value: 3), at: .init(light: 0)) == .empty)
        }

        @Test func `a readout's accent mixes its colours by heat, as written, then toward its finish`() throws {
            guard let sans = Self.sans else { return }
            let style = Self.readout(sans, value: 0).style
            #expect(style.lit(heat: 0, finished: 0) == .white)
            #expect(style.lit(heat: 1, finished: 0) == Picture.Color(hex: 0xFF0000))
            #expect(style.lit(heat: 0.5, finished: 0) == Picture.Color.white.mixed(inSRGBTo: Picture.Color(hex: 0xFF0000), at: 0.5))
            #expect(style.lit(heat: 0.5, finished: 1) == Picture.Color(hex: 0x0000FF))
        }

        @Test func `a caption's plate centres the whole line on its place, its last baseline through it`() throws {
            guard let mono = Self.mono else { return }
            let caption = Motion.Graphics.Caption(
                .init(.label("note:", Picture.Color(hex: 0x00FFFF)), "declared here"),
                at: Picture.Plane.Point<2>([500, 400]),
                style: .init(
                    transcript: Self.transcript(mono),
                    plate: .init(color: Picture.Color(gray: 0, alpha: 0.9), ascent: 16, descent: 5, horizontal: 16, vertical: 12, radius: 8),
                    rise: 20
                )
            )
            let plate = try caption.plate
            let width = try caption.transcript.width
            #expect(Swift.abs((plate.llx.underlying + plate.urx.underlying) / 2 - 500) < 1e-9)
            #expect(Swift.abs(plate.urx.underlying - plate.llx.underlying - width - 32) < 1e-9)
            #expect(plate.lly.underlying == 400 - 16 - 12)
            #expect(plate.ury.underlying == 400 + 5 + 12)
            #expect(try Picture(caption, at: .hidden) == .empty)
            #expect(try Picture(caption, at: .resting).elements.count == 1 + 2)
        }

        @Test func `a window's body stands under its bar, and a window hidden draws nothing`() throws {
            guard let sans = Self.sans else { return }
            let window = Motion.Graphics.Window(
                frame: Picture.Plane.Rectangle(llx: 10, lly: 10, urx: 410, ury: 310),
                title: "~/film — zsh",
                style: .init(
                    title: Self.ink(sans, 14),
                    radius: 12,
                    bar: 30,
                    line: 2,
                    edge: .white,
                    rule: .white,
                    fill: .clear,
                    lights: .init(count: 3, radius: 5, inset: 20, step: 16, color: Picture.Color(hex: 0xFF0000))
                )
            )
            #expect(window.body == Picture.Plane.Rectangle(llx: 10, lly: 42, urx: 410, ury: 310))
            #expect(try Picture(window, at: .hidden) == .empty)
            #expect(try Picture(window, at: .resting).elements.count == 2 + 3 + 1)
        }
    }
#endif
