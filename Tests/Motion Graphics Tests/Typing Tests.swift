#if Graphics
    import Motion
    import Picture
    import Testing

    @testable import Motion_Graphics

    @Suite struct `Typing Tests` {
        static var cadence: Motion.Graphics.Typing.Cadence {
            get throws {
                Motion.Graphics.Typing.Cadence(
                    spread: try Rational(numerator: 1, denominator: 2),
                    word: try Rational(numerator: 3, denominator: 2),
                    space: try Rational(numerator: 7, denominator: 10)
                )
            }
        }

        static var end: Rational {
            get throws { try Rational(numerator: 9, denominator: 2) }
        }

        @Test func `a cadence strikes one key for each character, the first at the start and the last at the end, never going back`() throws {
            let text = "swift build --product film"
            let typing = Motion.Graphics.Typing(text, key: Threefry.Key(1, 2), cadence: try Self.cadence, from: Rational(1), to: try Self.end)
            #expect(typing.strokes.count == text.count)
            #expect(typing.strokes.first == Rational(1))
            let end = try Self.end
            #expect(typing.strokes.last == end)
            #expect(zip(typing.strokes, typing.strokes.dropFirst()).allSatisfy { $0 <= $1 })
            #expect(Motion.Graphics.Typing("", key: Threefry.Key(1, 2), cadence: try Self.cadence, from: .zero, to: try Self.end).strokes.isEmpty)
        }

        @Test func `a cadence's instants are a function of its key: one key types alike, another otherwise`() throws {
            let text = "proceeding anyway, as asked"
            let one = Motion.Graphics.Typing(text, key: Threefry.Key(55, 7), cadence: try Self.cadence, from: .zero, to: try Self.end)
            let again = Motion.Graphics.Typing(text, key: Threefry.Key(55, 7), cadence: try Self.cadence, from: .zero, to: try Self.end)
            let other = Motion.Graphics.Typing(text, key: Threefry.Key(56, 7), cadence: try Self.cadence, from: .zero, to: try Self.end)
            #expect(one == again)
            #expect(one != other)
        }

        @Test func `without spread a gap is a plain gap, times the word's before a word and the space's before a space`() throws {
            let even = Motion.Graphics.Typing.Cadence(spread: .zero, word: try Rational(numerator: 3, denominator: 2), space: try Rational(numerator: 7, denominator: 10))
            let typing = Motion.Graphics.Typing("ab c", key: Threefry.Key(9, 9), cadence: even, from: .zero, to: try Rational(numerator: 16, denominator: 5))
            #expect(typing.strokes == [.zero, Rational(1), try Rational(numerator: 17, denominator: 10), try Rational(numerator: 16, denominator: 5)])
        }

        @Test func `a gap's draw is the top ten bits of the key's block at the character's position`() throws {
            let text = "a typist's rhythm"
            let key = Threefry.Key(1, 0x7479_7065)
            let characters = Swift.Array(text)
            let weights = try characters.indices.dropFirst().map { position in
                let bits = Int(Threefry.block(key: key, counter: Threefry.Block(UInt64(position), 0)).first >> 54)
                let after = characters[position - 1] == " " ? 3 : 2
                let space = characters[position] == " " ? 7 : 10
                return try Rational(numerator: (512 + bits) * after * space, denominator: 1024 * 2 * 10)
            }
            let expected = Motion.Graphics.Typing(Cardinal(UInt(characters.count)), from: .zero, to: try Self.end, weights: weights)
            #expect(Motion.Graphics.Typing(text, key: key, cadence: try Self.cadence, from: .zero, to: try Self.end) == expected)
        }
    }
#endif
