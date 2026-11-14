#if Graphics
    import Picture

    /// Fonts made in memory, so that no test reads a file of the machine: every printable ASCII character a
    /// box, a triangle or a wedge of straight contours in turn, the space without ink, and anything else the
    /// font's missing glyph, a box. `sans` gives its outlines different advances; `mono` gives every glyph one
    /// advance and says it is fixed pitch.
    enum Fonts {
        static let sans = font(advances: [500, 250, 520, 600, 640], fixed: false)
        static let mono = font(advances: [600, 600, 600, 600, 600], fixed: true)

        static func be16(_ value: Int) -> [UInt8] {
            [UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
        }

        static func glyph(_ contours: [[(x: Int, y: Int)]]) -> [UInt8] {
            guard !contours.isEmpty else { return [] }
            let points = contours.flatMap { $0 }
            var ends: [UInt8] = []
            var last = -1
            contours.forEach { contour in
                last += contour.count
                ends += be16(last)
            }
            var xs: [UInt8] = []
            var ys: [UInt8] = []
            var previous = (x: 0, y: 0)
            points.forEach { point in
                xs += be16(point.x - previous.x)
                ys += be16(point.y - previous.y)
                previous = point
            }
            let header = be16(contours.count) + be16(0) + be16(0) + be16(0) + be16(0)
            return header + ends + be16(0) + points.map { _ in 1 } + xs + ys
        }

        /// Glyph 0 is the missing glyph, 1 the space, and 2, 3 and 4 a box, a triangle and a wedge, which the
        /// printable characters take in turn by their code point.
        static func font(advances: [UInt16], fixed: Bool) -> ISO_14496_22.FontFile {
            let glyphs = [
                glyph([[(40, 0), (460, 0), (460, 700), (40, 700)]]),
                glyph([]),
                glyph([[(30, 0), (470, 0), (470, 700), (30, 700)]]),
                glyph([[(20, 0), (560, 0), (290, 700)]]),
                glyph([[(20, 700), (310, 0), (600, 700)], [(200, 500), (420, 500), (310, 300)]]),
            ]
            var mapping: [UInt32: UInt16] = [0x20: 1]
            for scalar in UInt32(0x21)...0x7E {
                mapping[scalar] = UInt16(2 + scalar % 3)
            }
            let offsets = glyphs.reduce(into: [UInt32(0)]) { $0.append(($0.last ?? 0) + UInt32($1.count)) }
            return ISO_14496_22.FontFile(
                data: [],
                head: ISO_14496_22.HeadTable(unitsPerEm: 1000),
                hhea: ISO_14496_22.HheaTable(ascender: 800, descender: -200, lineGap: 100, advanceWidthMax: advances.max() ?? 0, numberOfHMetrics: 5),
                hmtx: ISO_14496_22.HmtxTable(
                    hMetrics: advances.map { ISO_14496_22.LongHorMetric(advanceWidth: $0, leftSideBearing: 0) },
                    leftSideBearings: [],
                    numberOfHMetrics: 5
                ),
                maxp: ISO_14496_22.MaxpTable(numGlyphs: 5),
                cmap: ISO_14496_22.CmapTable(version: 0, encodingRecords: [], unicodeMapping: mapping),
                name: ISO_14496_22.NameTable(format: 0, nameRecords: [], strings: [:]),
                post: ISO_14496_22.PostTable(
                    version: ISO_14496_22.Fixed(integer: 3, fraction: 0),
                    italicAngle: 0,
                    underlinePosition: -100,
                    underlineThickness: 50,
                    isFixedPitch: fixed
                ),
                loca: ISO_14496_22.LocaTable(offsets: offsets),
                glyf: ISO_14496_22.GlyfTable(data: glyphs.flatMap { $0 }.map(Byte.init(_:)), tableOffset: 0),
                kern: nil
            )
        }
    }
#endif
