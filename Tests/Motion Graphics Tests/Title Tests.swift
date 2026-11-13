#if Graphics
    import Motion
    import Picture
    import Testing

    @testable import Motion_Graphics

    @Suite struct `Title Tests` {
        typealias Tests = `Graphics Tests`

        static let red = Picture.Color(hex: 0xFF0000)
        static let blue = Picture.Color(hex: 0x0000FF)

        static func title(_ font: ISO_14496_22.FontFile) -> Motion.Graphics.Title {
            Motion.Graphics.Title(
                ["AB ", "CD"],
                at: Picture.Plane.Point<2>([600, 400]),
                anchor: .center,
                style: .init(
                    font: font,
                    size: 100,
                    runs: [.init(color: red, rise: 0.42, grow: 0, fade: 1.8), .init(color: blue, rise: -0.5, grow: 1.9, fade: 1.2)]
                )
            )
        }

        @Test func `a title hidden draws nothing, and at rest each letter stands where the whole line stands`() throws {
            guard let sans = Tests.sans else { return }
            let title = Self.title(sans)
            #expect(try Picture(title, at: .hidden) == .empty)
            let text = try title.text
            let letters = try title.letters(at: .resting(5))
            #expect(letters.count == 4)
            #expect(letters.map(\.color) == [Self.red, Self.red, Self.blue, Self.blue])
            #expect(letters.allSatisfy { $0.opacity == 1 })
            let start = 600 - text.width / 2
            for letter in letters {
                let placed = letter.transform.applied(to: Vector([letter.glyph.origin[0], letter.glyph.origin[1]]))
                #expect(Swift.abs(placed[0] - (start + letter.glyph.origin[0])) < 1e-9)
                #expect(Swift.abs(placed[1] - (400 + letter.glyph.origin[1])) < 1e-9)
            }
        }

        @Test func `a letter enters from its rise, at its growth, coming up from clear, and one not begun is not drawn`() throws {
            guard let sans = Tests.sans else { return }
            let title = Self.title(sans)
            let half = try title.letters(at: .init([0.5, 0, 0, 1, 0.5]))
            #expect(half.map(\.glyph.scalar) == ["A", "C", "D"])
            #expect(half.map(\.opacity) == [0.9, 1, 0.6])
            let rest = try title.letters(at: .resting(5))
            let cap = try Picture.Text.Metrics(font: sans, size: 100).cap
            let middle = { (letter: Motion.Graphics.Title.Letter) -> Vector<2, Double> in
                guard let box = letter.glyph.path.boundingBox else { return Vector([0, 0]) }
                return letter.transform.applied(to: Vector([(box.llx.underlying + box.urx.underlying) / 2, -cap / 2]))
            }
            #expect(Swift.abs(middle(half[0])[1] - middle(rest[0])[1] - 0.5 * 0.42 * 100) < 1e-9)
            #expect(Swift.abs(middle(half[2])[1] - middle(rest[3])[1] + 0.5 * 0.5 * 100) < 1e-9)
            #expect(Swift.abs(middle(half[2])[0] - middle(rest[3])[0]) < 1e-9)
            #expect(try Picture(title, at: .init([0.5])).elements.count == 1)
        }
    }
#endif
