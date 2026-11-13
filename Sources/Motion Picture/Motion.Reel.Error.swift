#if Picture
    public import Motion
    public import Picture
    public import W3C_PNG

    extension Motion.Reel {
        /// Why a proof was not printed.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// A sheet or still asked for a frame beyond the frames printed.
            case outside(Ordinal)

            /// The frames were not drawn.
            case frames(Motion.Hosting.Picture.Frames.Error)

            /// A sheet's tiles could not be laid out.
            case sheet(Raster<Picture::Picture.Pixel>.Error)

            /// A picture could not be made a PNG image.
            case png(W3C_PNG.Image.Error)
        }
    }
#endif
