#if Graphics
    public import Motion
    import Picture

    extension Motion.Graphics.Transcript {
        /// One line: its mark and its words. A line feed in the words starts a new row.
        public struct Line: Sendable, Hashable {
            public var mark: Mark
            public var text: Swift.String

            public init(_ mark: Mark, _ text: Swift.String) {
                self.mark = mark
                self.text = text
            }
        }
    }

    extension Motion.Graphics.Transcript.Line {
        /// How many glyphs the words are set as, `Typesetting.Text.length(of:)`: one for each unicode scalar but a line
        /// feed. It is what a typed share counts.
        public var length: Cardinal {
            Typesetting.Text.length(of: text)
        }

        /// The cells the mark and the space after it take, before the words: one for each of the mark's glyphs.
        var lead: Int {
            switch mark {
            case .prompt(let word), .label(let word, _): Int(bitPattern: Typesetting.Text.length(of: word)) + 1
            case .plain: 0
            }
        }

        /// The rows of the words, each with how many of the line's glyphs come before it: each paragraph between
        /// line feeds, broken before a word that would end beyond the columns, the mark's cells counted, unless it
        /// stands alone on its row.
        func rows(within columns: Cardinal?) -> [(start: Int, words: Swift.String)] {
            let room = columns.map { Swift.max(Int(clamping: $0) - lead, 1) }
            var glyphs: [[UInt8]] = []
            for byte in text.utf8 {
                if byte & 0xc0 == 0x80, let last = glyphs.indices.last { glyphs[last].append(byte) } else { glyphs.append([byte]) }
            }
            var rows: [(start: Int, words: Swift.String)] = []
            var start = 0
            for paragraph in glyphs.split(separator: [0x0a], omittingEmptySubsequences: false) {
                rows += Self.wrapped(Swift.Array(paragraph), within: room).map { (start + $0.start, $0.words) }
                start += paragraph.count
            }
            return rows
        }

        /// A paragraph of glyphs, each its bytes in UTF-8, broken into rows of at most `room` glyphs at its spaces,
        /// each with how many of the paragraph's glyphs come before it; the spaces at a break end no row and start
        /// none, though they are counted among the glyphs.
        static func wrapped(_ paragraph: [[UInt8]], within room: Int?) -> [(start: Int, words: Swift.String)] {
            func words(_ glyphs: ArraySlice<[UInt8]>) -> Swift.String {
                Swift.String(decoding: glyphs.joined(), as: UTF8.self)
            }
            guard let room, paragraph.count > room else { return [(0, words(paragraph[...]))] }
            var rows: [(start: Int, words: Swift.String)] = []
            var row = 0
            var end: Int?
            for word in paragraph.split(separator: [0x20]) {
                if let last = end, word.endIndex - row > room {
                    rows.append((row, words(paragraph[row..<last])))
                    row = word.startIndex
                }
                end = word.endIndex
            }
            rows.append((row, words(paragraph[row...])))
            return rows
        }
    }
#endif
