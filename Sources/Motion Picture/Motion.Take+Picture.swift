#if Picture
    public import Matrix
    public import Motion
    public import Picture

    extension Picture {
        /// The frame a take shows at an instant in seconds from its start, `frame(at:outside:)`, as
        /// `init(_:placement:sampling:edge:)` of the frame places it. Outside the frames, before zero and from the
        /// end of the last frame on, it is the empty picture for `.empty`, the default, and the first or the last
        /// frame held for `.extend`. A part or a layer of a reel shows a take by asking it at its frame's `time`:
        /// at the reel's rate frame k shows the take's frame k, and at another rate the frame whose span holds
        /// the reel frame's center.
        public init(
            _ take: Motion.Take,
            at instant: Rational,
            outside: Motion.Take.Edge = .empty,
            placement: Picture.Transform = .identity,
            sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
            edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
        ) {
            self.init(take, at: instant, outside: outside, placement: Matrix<3, 3, Double>(placement), sampling: sampling, edge: edge)
        }

        /// `init(_:at:outside:placement:sampling:edge:)` under a projective placement.
        public init(
            _ take: Motion.Take,
            at instant: Rational,
            outside: Motion.Take.Edge = .empty,
            placement: Matrix<3, 3, Double>,
            sampling: Raster<Picture.Pixel>.Sampling = .bilinear,
            edge: Raster<Picture.Pixel>.Edge = .constant(.transparent)
        ) {
            guard let frame = take.frame(at: instant, outside: outside) else {
                self = .empty
                return
            }
            self.init(frame, placement: placement, sampling: sampling, edge: edge)
        }
    }
#endif
