#if Picture
    public import Motion
    public import Picture

    extension Motion.Take.Frame: Picture::Picture.Image.Drawing {
        /// The frame's raster as working pixels, read when the renderer asks for it, as `raster()` reads it; it
        /// draws nothing through the renderer. A frame whose pixels cannot be read fails the drawing with
        /// `.drawing` of the take's own error, as `raster()` gives it.
        public func raster(through renderer: Picture::Picture.Renderer) throws(Picture::Picture.Renderer.Error) -> Raster<Picture::Picture.Pixel> {
            do throws(Motion.Take.Error) {
                return Raster<Picture::Picture.Pixel>(try raster())
            } catch {
                throw .drawing(.init(error))
            }
        }
    }
#endif
