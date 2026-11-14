#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// Lines of a headline, set at the one size that fits the widest to a measure, centred as a block on a
        /// point. Each line rises into place out of a slot that clips it, and leaves upward out of the same slot.
        /// Inside an optional region the lines are inked in the style's second colour, so a headline can read
        /// across a shape that passes behind it. The lines are set once, when the headline is made.
        public struct Headline: Sendable {
            public let lines: [Line]
            /// The block's middle: across, the lines' centre; down, midway between the first line's capitals'
            /// top and the last line's baseline.
            public var centre: Picture.Plane.Point<2>
            /// Where the lines take the second ink, in the picture's space.
            public var region: Picture.Plane.Path?
            public let style: Style
            /// The size the lines are set at: the size at which the widest is as wide as the measure, and at most
            /// the style's size.
            public let size: Double
            /// The font's cap height at that size.
            let cap: Double
            /// Each line set at that size.
            let texts: [Picture.Text]

            /// A headline, its lines set once: it fails as `Picture.Text` does for its lines in the style's font.
            public init(_ lines: [Line], about centre: Picture.Plane.Point<2>, region: Picture.Plane.Path? = nil, style: Style) throws(Picture.Text.Error) {
                self.lines = lines
                self.centre = centre
                self.region = region
                self.style = style
                let block = try Picture.Text(lines.map(\.text).joined(separator: "\n"), font: style.font, size: style.size)
                let size = block.size(fitting: style.measure, maximum: style.size)
                self.size = size
                self.cap = try Picture.Text.Metrics(font: style.font, size: size).cap
                var texts: [Picture.Text] = []
                for line in lines {
                    texts.append(try Picture.Text(line.text, font: style.font, size: size))
                }
                self.texts = texts
            }
        }
    }

    extension Motion.Graphics.Headline {
        /// Each line's baseline when the block has opened by a share: the lines `pitch` sizes apart about the
        /// centre, the first line moved from where it stands alone, its capitals centred, to its place in the
        /// block as the share goes from 0 to 1.
        func baselines(opened: Double) -> [Double] {
            let pitch = style.pitch * size
            let middle = centre[1]
            let first = middle + (cap - pitch * Double(lines.indices.last ?? 0)) / 2
            let alone = middle + cap / 2
            return lines.indices.map { index in
                let baseline = first + Double(index) * pitch
                return index == 0 ? alone + (baseline - alone) * opened : baseline
            }
        }

        /// Where the lines stand at a moment: each line that has a moment, has begun to rise and has not wholly
        /// gone, as it was set, its baseline lowered by `(1 − risen) × rise` sizes and raised by `gone × rise`
        /// sizes, in a slot `slot.height` sizes tall whose top is `slot.above` sizes over the line's resting
        /// baseline, `span` wide about the centre.
        public func placements(at moment: Moment) -> [Placement] {
            let baselines = baselines(opened: moment.opened)
            var placements: [Placement] = []
            for (index, state) in zip(lines.indices, moment.lines) where state.risen > 0 && state.gone < 1 {
                let lift = ((1 - state.risen) - state.gone) * size * style.rise
                let top = baselines[index] - size * style.slot.above
                let slot = Picture.Plane.Rectangle(
                    llx: .init(centre[0] - style.span / 2),
                    lly: .init(top),
                    urx: .init(centre[0] + style.span / 2),
                    ury: .init(top + size * style.slot.height)
                )
                let point = Picture.Plane.Point<2>([centre[0] + lines[index].offset, baselines[index] + lift])
                placements.append(Placement(text: texts[index], point: point, slot: Picture.Plane.Path(slot)))
            }
            return placements
        }
    }
#endif
