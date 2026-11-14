#if Picture
    public import Motion
    public import Picture
    public import Picture_PNG_Integration

    extension Motion.Pairs {
        /// Why a sheet of pairs was not made.
        public enum Error: Swift.Error, Sendable {
            /// The tiles could not be laid out.
            case sheet(Raster<Picture::Picture.Pixel>.Error)

            /// A label could not be set in its font.
            case label(Typesetting.Error)

            /// The renderer refused a label.
            case renderer(Picture::Picture.Renderer.Error)

            /// The sheet could not be made a PNG image.
            case png(W3C_PNG::W3C_PNG.Image.Error)
        }
    }
#endif
