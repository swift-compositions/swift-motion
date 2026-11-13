#if Picture
    public import Motion
    public import Picture
    import Picture_CPU
    import Witnesses

    extension Motion.Hosting {
        /// Draws a picture, where the other hosts draw a view.
        ///
        /// It asks the renderer in the current `Witness.Context` to draw, which is `Picture.Renderer.cpu`
        /// unless the caller set another with `withWitnesses`. It needs no window, no screen and no
        /// permission, and it holds no state, so frames can be drawn on any thread and in any order.
        public enum Picture {}
    }

    extension Motion.Hosting.Picture {
        /// The picture drawn at `width` by `height` pixels over `background`, as a frame.
        ///
        /// The picture's point (x, y) is the frame's position (x, y), the first row on top. It is drawn
        /// in linear light and then turned into the frame's sRGB pixels one by one. A renderer that
        /// fails gives no frame, and its failure is thrown as it is.
        public static func raster(
            _ picture: Picture::Picture,
            width: Cardinal,
            height: Cardinal,
            over background: Picture::Picture.Color = .black
        ) throws(Picture::Picture.Renderer.Error) -> Raster<Motion.Pixel> {
            var drawn = Raster<Picture::Picture.Pixel>(width: width, height: height, repeating: background.pixel)
            try Witness.Context[Picture::Picture.Renderer.self].render(picture, into: &drawn)
            return drawn.map { pixel in Motion.Pixel(pixel) }
        }
    }
#endif
