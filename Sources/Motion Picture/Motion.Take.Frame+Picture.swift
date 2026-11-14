#if Picture
    public import Matrix
    public import Motion
    public import Picture
    import Vector

    extension Picture {
        /// A take's frame as a picture: the quadrilateral its four corners, (0, 0), (width, 0), (width, height)
        /// and (0, height), go to under the placement, by `projected(_:)` of swift-matrix, filled with
        /// `Picture.Image(frame, placement:sampling:edge:)`, the image that names the frame as its drawing. So it
        /// is placed, scaled, turned or seen in perspective like any image, and composes under groups, layers,
        /// effects and glass. With the identity the frame's pixel (x, y) covers the points from (x, y) to
        /// (x + 1, y + 1). The edge shows only where sampling reaches past the frame's border; to show more of it,
        /// fill a wider area with the image.
        public init(
            _ frame: Motion.Take.Frame,
            placement: Matrix<3, 3, Double>,
            sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
            edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
        ) {
            let (width, height) = (Double(Int(clamping: frame.width)), Double(Int(clamping: frame.height)))
            let corners = [(0, 0), (width, 0), (width, height), (0, height)].map { x, y in
                let point = placement.projected(Vector([x, y]))
                return Picture.Plane.Point<2>([point[0], point[1]])
            }
            let area = Picture.Plane.Path([Picture.Plane.Polygon(vertices: corners)])
            self = [.fill(area, .image(Picture.Image(frame, placement: placement, sampling: sampling, edge: edge)))]
        }

        /// A take's frame under an affine placement: `init(_:placement:sampling:edge:)` of its lift.
        public init(
            _ frame: Motion.Take.Frame,
            placement: Picture.Transform = .identity,
            sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
            edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
        ) {
            self.init(frame, placement: Matrix<3, 3, Double>(placement), sampling: sampling, edge: edge)
        }
    }
#endif
