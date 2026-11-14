#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A title at a moment: each of its `letters(at:)` filled in its colour where its transform puts it, in a
        /// layer of its opacity while it is not yet whole.
        public init(_ title: Motion.Graphics.Title, at moment: Motion.Graphics.Title.Moment) {
            self.init(
                title.letters(at: moment).map { letter in
                    let placed = Picture.Element.group(Picture.Group([.fill(Picture.Plane.Path(letter.glyph.path), .solid(letter.color))], transform: letter.transform))
                    return letter.opacity < 1 ? .layer(Picture.Layer([placed], opacity: Float(letter.opacity))) : placed
                }
            )
        }
    }
#endif
