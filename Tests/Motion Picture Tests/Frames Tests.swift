#if Picture
    import Motion
    import Motion_Picture
    import Picture
    import Picture_CPU
    import Picture_Store
    import File_System
    import RFC_1951
    import Test_Apple
    import Testing

    @Suite(.deadline(.seconds(180))) struct `Frames Tests` {
        typealias Tests = `Picture Tests`

        static let width: Cardinal = 48
        static let height: Cardinal = 30
        static let paper = Picture.Color(red: 0.96, green: 0.94, blue: 0.9)

        /// A part that is the same in every frame, as an image that names its picture.
        static let still: Picture.Image = Picture.Image(
            [
                Tests.rectangle(0, 0, 12, 12, Picture.Color(red: 0.1, green: 0.2, blue: 0.5)),
                Tests.rectangle(3, 2, 6.5, 4.25, Picture.Color(red: 0.9, green: 0.8, blue: 0.1, alpha: 0.6)),
            ],
            in: Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 12, ury: 12),
            scale: 2
        )

        static func square(_ x: Double, _ y: Double, _ side: Double, _ paint: Picture.Paint) -> Picture.Element {
            guard case .shape(var shape) = Tests.rectangle(x, y, side, side, .black) else { return Tests.rectangle(x, y, side, side, .black) }
            shape.fill = .init(paint)
            return .shape(shape)
        }

        /// The picture at a position: something that moves, over the part that stays, shown twice.
        @Test func `frames kept in a store are read back as drawing gives them, in the form asked for`() async throws {
            let path = "/tmp/motion-frames-store-" + Swift.String(UInt64.random(in: 0...UInt64.max))
            let store = Picture.Store.cpu(File.Directory(try File.Path(validating: path)))
            let plain = Motion.Hosting.Picture.Frames(width: Self.width, height: Self.height, over: Self.paper, workers: 2, picture: Self.picture)
            var kept = plain
            kept.store = store
            let positions: [Ordinal] = [0, 1, 2, 3]
            let movie = try await plain.rasters(positions)
            #expect(try await kept.rasters(positions) == movie)
            let never = Motion.Hosting.Picture.Frames(width: Self.width, height: Self.height, over: Self.paper, workers: 2, renderer: .absent, store: store, picture: Self.picture)
            #expect(try await never.rasters(positions) == movie)
            let sheet = try await plain.sheet(positions, columns: 2)
            #expect(try await kept.sheet(positions, columns: 2) == sheet)
            #expect(try await never.sheet(positions, columns: 2) == sheet)
            let key = try #require(store.key(Self.picture(0), width: Self.width, height: Self.height, over: Self.paper.pixel, form: "Motion.Pixel deflate fast"))
            let entry = try #require(store.bytes(for: key))
            #expect(try RFC_1951.decompress(entry).count == 16 + 4 * Int(clamping: Self.width) * Int(clamping: Self.height))
            await #expect(throws: Motion.Hosting.Picture.Frames.Error.self) { try await never.rasters([7]) }
        }

        @Test func `the deflated movie form reads back the frame the raw one does, value for value, and refuses what is not its own`() async throws {
            let raw = Motion.Hosting.Picture.Frames.Form<Raster<Motion.Pixel>>.movie
            let deflated = Motion.Hosting.Picture.Frames.Form<Raster<Motion.Pixel>>.deflated
            for raster in try await Self.frames(workers: 2).rasters([0, 1, 2, 3]) {
                let bytes = try #require(raw.bytes(raster))
                let kept = try #require(raw.frame(bytes))
                let packed = try #require(deflated.bytes(raster))
                let inflated = try #require(deflated.frame(packed))
                #expect(inflated == kept)
                #expect(kept == raster)
                #expect(packed.count < bytes.count)
                #expect(deflated.frame(bytes) == nil)
            }
            #expect(raw.name?(0) != deflated.name?(0))
        }

        @Sendable static func picture(_ position: Ordinal) -> Picture {
            let step = Double(Int(bitPattern: position))
            var moved = still
            moved.placement = Matrix<3, 3, Double>(Picture.Transform(rows: [[1, 0, 30], [0, 1, 14]])).multiplied(by: moved.placement)
            return [
                square(2, 2, 12, .image(still)),
                square(30, 14, 12, .image(moved)),
                Tests.rectangle(4 + step * 2.5, 6 + step * 0.75, 9, 7, Picture.Color(red: 0.85, green: 0.35, blue: 0.2, alpha: 0.8)),
                .layer(.init([Tests.rectangle(40 - step * 3, 3, 6, 20, Picture.Color(red: 0.2, green: 0.7, blue: 0.4))], effects: [.blur(.init(deviation: 1.5))])),
            ]
        }

        static func plain(_ position: Ordinal) throws -> Raster<Motion.Pixel> {
            try Motion.Hosting.Picture.raster(picture(position), width: width, height: height, over: paper)
        }

        static func frames(workers: Cardinal?) -> Motion.Hosting.Picture.Frames {
            Motion.Hosting.Picture.Frames(width: width, height: height, over: paper, workers: workers, picture: picture)
        }

        @Test func `frames drawn side by side are the frames drawn one by one, pixel for pixel, in the order asked, on any number of workers`() async throws {
            let positions: [Ordinal] = [7, 0, 3, 3, 11, 1, 2, 9, 4, 5, 6, 8, 10, 0]
            let expected = try positions.map(Self.plain)
            #expect(expected[0] != expected[1])
            for workers: Cardinal? in [1, 2, 5, 32, nil] {
                let frames = Self.frames(workers: workers)
                #expect(try await frames.rasters(positions) == expected)
                #expect(try await frames.rasters(positions) == expected)
                let places = try await frames.drawn(positions) { position, raster in
                    raster.width == Self.width && raster.height == Self.height ? position : .zero
                }
                #expect(places == positions)
            }
            #expect(try await Self.frames(workers: 3).rasters([]).isEmpty)
            #expect(Self.frames(workers: 0).workers == 1)
        }

        @Test func `a sheet is the frames made smaller by the box filter and tiled, a row of columns at a time`() async throws {
            let positions: [Ordinal] = [0, 2, 4, 6, 8]
            let sheet = try await Self.frames(workers: 3).sheet(positions, columns: 3, gap: 2, fill: .white)
            let tiles = try positions.map { position in
                var raster = Raster<Picture.Pixel>(width: Self.width, height: Self.height, repeating: Self.paper.pixel)
                try Picture.Renderer.cpu(threads: 1).render(Self.picture(position), into: &raster)
                return raster.resampled(width: 16, height: 10, .box) { (from: Picture.Pixel, to: Picture.Pixel, parameter: Float) in
                    from.interpolated(to: to, at: parameter)
                }
            }
            #expect(try sheet == Raster(tiling: tiles, columns: 3, gap: 2, fill: Picture.Color.white.pixel))
            #expect(sheet.width == Cardinal(52))
        }

        @Test func `a feed hands over every frame once asked in order, the same frame when asked again or out of order, and nothing past the end`() async throws {
            let feed = Self.frames(workers: 3).feed(first: 10, ahead: 4)
            for position: Ordinal in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 2, 7] {
                #expect(try await feed.frame(at: position) == Self.plain(position))
            }
            #expect(try await feed.frame(at: 10) == nil)
            #expect(try await feed.frame(at: 400) == nil)
            let places = Self.frames(workers: 2).feed(first: 3) { position, _ in position }
            #expect(try await places.frame(at: 2) == 2)
            #expect(try await places.frame(at: 3) == nil)
        }

        @Test func `a frame the renderer refuses fails the run with its position`() async throws {
            let frames = Motion.Hosting.Picture.Frames(width: Self.width, height: Self.height, workers: 4) { position in
                guard position == 5 else { return Self.picture(position) }
                let empty = Picture.Image(.empty, in: Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 0, ury: 4), scale: 1)
                return [Self.square(0, 0, 4, .image(empty))]
            }
            await #expect(throws: Motion.Hosting.Picture.Frames.Error.renderer(.unsupported, at: 5)) {
                _ = try await frames.rasters([0, 1, 2, 3, 4, 5, 6, 7])
            }
            await #expect(throws: Motion.Hosting.Picture.Frames.Error.renderer(.unsupported, at: 5)) {
                _ = try await frames.feed(first: 8).frame(at: 1)
            }
            #expect(try await frames.rasters([0, 1, 2, 3, 4]).count == 5)
        }
    }

    #if canImport(Darwin)
        import Darwin

        extension `Frames Tests` {
            /// The threads of this process, as the kernel counts them.
            static func threads() -> Int {
                var list: thread_act_array_t?
                var count: mach_msg_type_number_t = 0
                guard unsafe task_threads(mach_task_self_, &list, &count) == KERN_SUCCESS, let list = unsafe list else { return 0 }
                unsafe UnsafeBufferPointer(start: list, count: Int(count)).forEach { _ = unsafe mach_port_deallocate(mach_task_self_, $0) }
                let size = vm_size_t(MemoryLayout<thread_t>.stride * Int(count))
                _ = unsafe vm_deallocate(mach_task_self_, vm_address_t(bitPattern: list), size)
                return Int(count)
            }

            @Test func `a Frames holds its workers' threads while it is held, and they end when it is let go`() async throws {
                let before = Self.threads()
                let held = (0..<25).map { _ in
                    Motion.Hosting.Picture.Frames(width: Self.width, height: Self.height, over: Self.paper, workers: 4, picture: Self.picture)
                }
                #expect(Self.threads() >= before + 75, "\(before) threads before 25 Frames of 4 workers were made")
                _ = consume held
                for _ in 0..<60 {
                    let frames = Motion.Hosting.Picture.Frames(width: Self.width, height: Self.height, over: Self.paper, workers: 4, picture: Self.picture)
                    #expect(try await frames.rasters([0, 1, 2]).count == 3)
                }
                var after = Self.threads()
                for _ in 0..<100 where after > before + 64 {
                    try await Task.sleep(for: .milliseconds(50))
                    after = Self.threads()
                }
                #expect(before > 0)
                #expect(after <= before + 64, "\(before) threads before, \(after) after 85 Frames of 4 workers were made, 60 used, and let go")
            }
        }
    #endif
#endif
