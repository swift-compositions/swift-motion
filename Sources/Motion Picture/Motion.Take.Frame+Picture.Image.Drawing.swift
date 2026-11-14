#if Picture
    public import Motion
    public import Picture

    extension Motion.Take.Frame: Picture::Picture.Image.Drawing {
        /// The frame's raster as working pixels; it draws nothing through the renderer.
        public func raster(through renderer: Picture::Picture.Renderer) throws(Picture::Picture.Renderer.Error) -> Raster<Picture::Picture.Pixel> {
            Raster<Picture::Picture.Pixel>(raster)
        }
    }
#endif
