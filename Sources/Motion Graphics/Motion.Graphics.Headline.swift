#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// Lines of a headline, set at the one size that fits the widest to a measure, centred as a block on a
        /// point. Each line rises into place out of a slot that clips it, and leaves upward out of the same slot.
        /// Inside an optional region the lines are inked in the style's second colour, so a headline can read
        /// across a shape that passes behind it.
        public struct Headline: Sendable {
            public var lines: [Line]

            /// The block's middle: across, the lines' centre; down, midway between the first line's capitals'
            /// top and the last line's baseline.
            public var centre: Picture.Plane.Point<2>

            /// Where the lines take the second ink, in the picture's space.
            public var region: Picture.Plane.Path?

            public var style: Style

            public init(_ lines: [Line], about centre: Picture.Plane.Point<2>, region: Picture.Plane.Path? = nil, style: Style) {
                self.lines = lines
                self.centre = centre
                self.region = region
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Headline {
        /// The size the lines are set at: the size at which the widest is as wide as the measure, and at most
        /// the style's size.
        public var size: Double {
            get throws(Picture.Text.Error) {
                let block = try Picture.Text(lines.map(\.text).joined(separator: "\n"), font: style.font, size: style.size)
                return block.size(fitting: style.measure, maximum: style.size)
            }
        }

        /// Each line's baseline when the block has opened by a share: the lines `pitch` sizes apart about the
        /// centre, the first line moved from where it stands alone, its capitals centred, to its place in the
        /// block as the share goes from 0 to 1.
        func baselines(opened: Double) throws(Picture.Text.Error) -> [Double] {
            let size = try size
            let cap = try Picture.Text.Metrics(font: style.font, size: size).cap
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
        /// gone, set at the fitted size, its baseline lowered by `(1 − risen) × rise` sizes and raised by
        /// `gone × rise` sizes, in a slot `slot.height` sizes tall whose top is `slot.above` sizes over the
        /// line's resting baseline, `span` wide about the centre.
        public func placements(at moment: Moment) throws(Picture.Text.Error) -> [Placement] {
            let size = try size
            let baselines = try baselines(opened: moment.opened)
            var placements: [Placement] = []
            for (index, state) in zip(lines.indices, moment.lines) where state.risen > 0 && state.gone < 1 {
                let text = try Picture.Text(lines[index].text, font: style.font, size: size)
                let lift = ((1 - state.risen) - state.gone) * size * style.rise
                let top = baselines[index] - size * style.slot.above
                let slot = Picture.Plane.Rectangle(
                    llx: .init(centre[0] - style.span / 2),
                    lly: .init(top),
                    urx: .init(centre[0] + style.span / 2),
                    ury: .init(top + size * style.slot.height)
                )
                let point = Picture.Plane.Point<2>([centre[0] + lines[index].offset, baselines[index] + lift])
                placements.append(Placement(text: text, point: point, slot: Picture.Plane.Path(slot)))
            }
            return placements
        }
    }
#endif
