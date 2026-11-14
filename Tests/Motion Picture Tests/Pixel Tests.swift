#if Picture
    import Motion
    import Motion_Picture
    import Picture
    import Testing

    @Suite struct `Pixel Tests` {
        @Test func `an opaque frame's pixel is its levels' linear light, within a millionth of its colour's; any other is its colour's`() throws {
            for level in UInt8.min...UInt8.max {
                let opaque = try #require(Motion.Pixel(blue: level, green: 255 - level, red: level / 2, alpha: 255))
                let working = Picture::Picture.Pixel(opaque)
                let colour = Picture::Picture.Color(opaque).pixel
                #expect(working.color.blue == Motion.Pixel.linear(level) && working.alpha == 1)
                #expect(abs(working.color.blue - colour.color.blue) <= colour.color.blue * 1e-6)
                #expect(abs(working.color.green - colour.color.green) <= colour.color.green * 1e-6)
                #expect(abs(working.color.red - colour.color.red) <= colour.color.red * 1e-6)
                let cover = Swift.min(Swift.max(level, 1), 254)
                let under = try #require(Motion.Pixel(blue: cover / 3, green: cover, red: 0, alpha: cover))
                #expect(Picture::Picture.Pixel(under) == Picture::Picture.Color(under).pixel)
            }
        }

        @Test func `an opaque frame's pixel becomes a working pixel and comes back as itself`() throws {
            for level in UInt8.min...UInt8.max {
                let pixel = try #require(Motion.Pixel(blue: level, green: level, red: level, alpha: 255))
                #expect(Motion.Pixel(Picture::Picture.Pixel(pixel)) == pixel)
            }
        }
    }
#endif
