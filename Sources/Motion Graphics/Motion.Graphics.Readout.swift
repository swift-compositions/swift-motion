#if Graphics
    import Formatter
    public import Motion
    public import Picture

    extension Motion.Graphics {
        /// A small heads-up readout on a plate: a label, a count in tabular figures padded with zeros to as many
        /// digits as its total, the total after a word between them, and a bar under them that the count's share
        /// of the total fills.
        public struct Readout: Sendable {
            public var label: Swift.String

            /// The word between the count and the total, such as `/ `.
            public var of: Swift.String
            public var value: Cardinal
            public var total: Cardinal

            /// A point of the plate's top edge: its left end, its middle or its right end, as `anchor` says.
            public var place: Picture.Plane.Point<2>
            public var anchor: Picture.Text.Alignment
            public var style: Style

            public init(
                _ label: Swift.String,
                value: Cardinal,
                of: Swift.String,
                total: Cardinal,
                at place: Picture.Plane.Point<2>,
                anchor: Picture.Text.Alignment,
                style: Style
            ) {
                self.label = label
                self.value = value
                self.of = of
                self.total = total
                self.place = place
                self.anchor = anchor
                self.style = style
            }
        }
    }

    extension Motion.Graphics.Readout {
        /// The count as written: its digits, padded with zeros to as many as the total has.
        public var figures: Swift.String {
            let digits = Formatter.Number().format(Double(Int(clamping: total))).count
            return Formatter.Number(padding: Cardinal(UInt(digits))).format(Double(Int(clamping: value)))
        }

        /// The whole line: the label, a space, the count, a space, the word and the total, each digit tabular.
        var line: Swift.String {
            label + " " + figures + " " + rest
        }

        /// The word and the total.
        var rest: Swift.String {
            of + Formatter.Number().format(Double(Int(clamping: total)))
        }

        /// The line set in the ink's font at its size, in tabular figures.
        var set: Picture.Text {
            get throws(Picture.Text.Error) {
                try Picture.Text(line, font: style.ink.font, size: style.ink.size, figures: .tabular)
            }
        }

        /// The plate at rest, before the readout grows, turns or drops: as wide as the line and two insets,
        /// `plate.height` tall, its top edge through `place` at its left end, its middle or its right end as
        /// `anchor` says. Since the count's digits share one advance, it is the same whatever the count reads.
        public var plate: Picture.Plane.Rectangle {
            get throws(Picture.Text.Error) {
                plate(of: try set)
            }
        }

        /// The plate around a set line.
        func plate(of set: Picture.Text) -> Picture.Plane.Rectangle {
            let wide = set.width + 2 * style.plate.inset
            let left = place[0] - anchor.indent(of: 0, in: wide)
            let top = place[1]
            return Picture.Plane.Rectangle(llx: .init(left), lly: .init(top), urx: .init(left + wide), ury: .init(top + style.plate.height))
        }

        /// Where the readout stands at a moment: grown about the plate's middle from `1 − grow` of its size by how
        /// far it has shown, then turned by the tilt about the pivot and dropped. The plate at a moment is `plate`
        /// under this transform, and so is everything the readout draws.
        public func transform(at moment: Moment) throws(Picture.Text.Error) -> Picture.Transform {
            transform(at: moment, plate: try plate)
        }

        /// Where the readout stands at a moment, about a plate.
        func transform(at moment: Moment, plate: Picture.Plane.Rectangle) -> Picture.Transform {
            let (left, top) = (plate.llx.underlying, plate.lly.underlying)
            let middle = Picture.Plane.Point<2>([(left + plate.urx.underlying) / 2, (top + plate.ury.underlying) / 2])
            let grown = Picture.Transform.scale(1 - style.grow + style.grow * moment.shown, about: middle)
            let pivot = Picture.Plane.Point<2>([left + style.pivot[0], top + style.pivot[1]])
            let turned = Picture.Transform.translation(x: 0, y: moment.drop).multiplied(by: .rotation(Radian(moment.tilt), about: pivot))
            return turned.multiplied(by: grown)
        }

        /// The share of the total the count has come to, 0 to 1; a total of nothing is full.
        public var share: Double {
            let total = Double(Int(clamping: total))
            guard total > 0 else { return 1 }
            return Swift.min(Double(Int(clamping: value)) / total, 1)
        }
    }
#endif
