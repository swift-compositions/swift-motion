#if Picture
    import Motion
    import Motion_Picture
    import Picture
    import Picture_Store
    import File_System
    import Testing

    @Suite struct `Key Tests` {
        static let store = Picture.Store.cpu(File.Directory(File.Path("/tmp/motion-key-tests")))

        static func key(_ picture: Picture) -> Picture.Store.Key? {
            store.key(picture, width: 64, height: 48, over: Picture.Color.black.pixel, form: "Motion.Pixel")
        }

        static let sprites: [Picture.Sprites.Sprite] = (0..<100).map(sprite)

        static func sprite(_ index: Int) -> Picture.Sprites.Sprite {
            let step = Double(index)
            let x: Double = step / 2
            let y: Double = 40 - step / 4
            let center = Picture.Plane.Point<2>([x, y])
            let green = Float(index % 7) / 7
            return Picture.Sprites.Sprite(center: center, radius: 2 + step / 50, color: Picture.Color(red: 0.2, green: green, blue: 0.9))
        }

        /// Equal pictures whose parts share storage and equal pictures whose parts do not get different keys
        /// today, because `Swift.Mirror.Writer.again` writes a shared array as a reference to where it was met,
        /// so only pictures built alike are held to equal keys here.
        @Test func `equal pictures built alike have equal keys`() throws {
            let first: Picture = [.sprites(Picture.Sprites(Self.sprites)), .sprites(Picture.Sprites(Self.sprites))]
            let second: Picture = [.sprites(Picture.Sprites(Self.sprites)), .sprites(Picture.Sprites(Self.sprites))]
            #expect(first == second)
            let firstKey = try #require(Self.key(first))
            #expect(Self.key(second) == firstKey)
        }
    }
#endif
