#if Picture
    public import Motion
    public import Standard_Library_Extensions
    import FIPS_180_4

    extension Motion.Take.Frame: Swift.Mirror.Written {
        /// A frame writes its size and its digest for `Swift.Mirror.bytes(of:)`, which keys a picture holding it,
        /// and never its pixels, which the digest already decides. A test lists the frame's stored properties by
        /// `Mirror` and fails when one is added.
        public func write(into writer: Swift.Mirror.Writer) -> Bool {
            writer.number(UInt64(Int(clamping: raster.width)))
            writer.number(UInt64(Int(clamping: raster.height)))
            return writer.write(digest.bytes.map(\.underlying))
        }
    }
#endif
