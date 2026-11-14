#if Graphics
    import ISO_14496_22_Test_Support

    /// Fonts made in memory, so that no test reads a file of the machine: every printable ASCII character a
    /// box, a triangle or a wedge of straight contours in turn, the space without ink, and anything else the
    /// font's missing glyph, a box. `sans` gives its outlines different advances; `mono` gives every glyph one
    /// advance and says it is fixed pitch.
    enum Fonts {
        static let sans = font(advances: [500, 250, 520, 600, 640])
        static let mono = font(advances: [600, 600, 600, 600, 600]).fixed

        /// Glyph 0 is the missing glyph, 1 the space, and 2, 3 and 4 a box, a triangle and a wedge, which the
        /// printable characters take in turn by their code point.
        static func font(advances: [UInt16]) -> ISO_14496_22.FontFile {
            let contours: [[[(x: Int, y: Int)]]] = [
                [[(40, 0), (460, 0), (460, 700), (40, 700)]],
                [],
                [[(30, 0), (470, 0), (470, 700), (30, 700)]],
                [[(20, 0), (560, 0), (290, 700)]],
                [[(20, 700), (310, 0), (600, 700)], [(200, 500), (420, 500), (310, 300)]],
            ]
            var mapping: [UInt32: UInt16] = [0x20: 1]
            for scalar in UInt32(0x21)...0x7E {
                mapping[scalar] = UInt16(2 + scalar % 3)
            }
            return ISO_14496_22.FontFile(
                sketches: zip(advances, contours).map { ISO_14496_22.Sketch(advance: $0, contours: $1) },
                mapping: mapping
            )
        }
    }
#endif
