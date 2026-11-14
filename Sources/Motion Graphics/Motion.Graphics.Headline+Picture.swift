#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A headline at a moment: each placed line in the ink, centred on its point, and again in the second ink
        /// inside the region, both clipped to the line's slot.
        public init(_ headline: Motion.Graphics.Headline, at moment: Motion.Graphics.Headline.Moment) {
            let style = headline.style
            self.init(
                headline.placements(at: moment).map { placement in
                    var content: Picture = [placement.text.placed(.init(.solid(style.ink)), at: placement.point, anchor: .center)]
                    if let region = headline.region {
                        let inked: Picture = [placement.text.placed(.init(.solid(style.second)), at: placement.point, anchor: .center)]
                        content.elements.append(.group(Picture.Group(inked, clip: Picture.Clip(region))))
                    }
                    return .group(Picture.Group(content, clip: Picture.Clip(placement.slot)))
                }
            )
        }
    }
#endif
