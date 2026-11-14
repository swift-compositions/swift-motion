#if Picture
    public import Motion
    public import Picture
    public import Picture_PNG_Integration

    extension Motion.Reel {
        /// Why a frame of the reel was not drawn or a proof was not printed.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The drawing of the part or the layer with this key could not be built: its words did not set.
            case building(Key, Typesetting.Error)

            /// A sheet or still asked for a frame beyond the frames printed.
            case outside(Ordinal)

            /// The frames were not drawn.
            case frames(Motion.Hosting.Picture.Frames.Error)

            /// A sheet's tiles could not be laid out.
            case sheet(Raster<Picture::Picture.Pixel>.Error)

            /// A picture could not be made a PNG image.
            case png(W3C_PNG::W3C_PNG.Image.Error)
        }
    }
#endif
