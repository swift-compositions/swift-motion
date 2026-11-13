#if Picture
    public import Motion
    public import Picture
    public import Thread_Pool

    extension Motion.Hosting.Picture.Frames {
        /// Why frames were not drawn.
        public enum Error: Swift.Error, Sendable, Equatable {
            /// The renderer failed at the frame at a position.
            case renderer(Picture::Picture.Renderer.Error, at: Ordinal)

            /// The threads that draw refused the work.
            case pool(Kernel.Thread.Pool.Error)

            /// The frames could not be laid out as a sheet.
            case sheet(Raster<Picture::Picture.Pixel>.Error)
        }
    }
#endif
