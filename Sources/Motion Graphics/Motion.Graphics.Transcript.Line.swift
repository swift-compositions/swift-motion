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
        /// How many characters the words have, line feeds included: what a typed share counts.
        public var characters: Cardinal {
            Cardinal(UInt(text.count))
        }

        /// The cells the mark and the space after it take, before the words.
        var lead: Int {
            switch mark {
            case .prompt(let word), .label(let word, _): word.count + 1
            case .plain: 0
            }
        }

        /// How many characters stand at a typed share.
        func standing(_ share: Double) -> Int {
            Motion.Graphics.standing(share, of: text.count)
        }

        /// The rows of the words: each paragraph between line feeds, broken before a word that would end beyond
        /// the columns, the mark's cells counted, unless it stands alone on its row.
        func rows(within columns: Cardinal?) -> [Motion.Graphics.Transcript.Row] {
            let room = columns.map { Swift.max(Int(clamping: $0) - lead, 1) }
            let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false)
            let starts = paragraphs.reduce(into: [0]) { starts, paragraph in starts.append((starts.last ?? 0) + paragraph.count + 1) }
            return zip(paragraphs, starts).flatMap { paragraph, start in
                Self.wrapped(paragraph, from: start, within: room)
            }
        }

        /// The widest row's cells, the mark's included.
        func columns(within columns: Cardinal?) -> Int {
            lead + (rows(within: columns).map(\.text.count).max() ?? 0)
        }

        /// A paragraph broken into rows of at most `room` characters at its spaces; the spaces at a break end
        /// no row and start none, though they are counted among the characters.
        static func wrapped(_ paragraph: Substring, from start: Int, within room: Int?) -> [Motion.Graphics.Transcript.Row] {
            guard let room, paragraph.count > room else { return [Motion.Graphics.Transcript.Row(start: start, text: paragraph)] }
            var rows: [Motion.Graphics.Transcript.Row] = []
            var row = paragraph.startIndex
            var end: Substring.Index?
            for word in paragraph.split(separator: " ") {
                if let last = end, paragraph.distance(from: row, to: word.endIndex) > room {
                    rows.append(Motion.Graphics.Transcript.Row(start: start + paragraph.distance(from: paragraph.startIndex, to: row), text: paragraph[row..<last]))
                    row = word.startIndex
                }
                end = word.endIndex
            }
            rows.append(Motion.Graphics.Transcript.Row(start: start + paragraph.distance(from: paragraph.startIndex, to: row), text: paragraph[row...]))
            return rows
        }
    }
#endif
