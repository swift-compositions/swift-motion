public import Motion
public import Picture

extension Motion.Pixel {
    /// A picture's working pixel as a frame's pixel: linear light into sRGB, 32-bit components into
    /// eight bits, as `Motion.Pixel.init(linear:green:blue:alpha:)` says.
    public init(_ pixel: Picture::Picture.Pixel) {
        self.init(linear: pixel.color.red, green: pixel.color.green, blue: pixel.color.blue, alpha: pixel.alpha)
    }
}
