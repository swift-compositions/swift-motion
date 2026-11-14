#if Picture
    import Motion
    import Motion_Picture
    import Picture
    import Picture_PNG_Integration
    import Test_Apple
    import Testing
    import Synchronization
    import Timeline

    @Suite(.deadline(.seconds(180))) struct `Reel Tests` {
        typealias Tests = `Picture Tests`
        typealias Reel = Motion.Reel<String>

        static let width: Cardinal = 24
        static let height: Cardinal = 16

        /// A part whose picture is one rectangle that moves with the part's own frame, in its own colour.
        static func part(_ key: String, frames: Cardinal, _ color: Picture.Color) -> Reel.Part {
            Reel.Part(key, frames: frames) { frame in
                [Tests.rectangle(1 + Double(Int(bitPattern: frame.position)) * 2, 2, 5, 6, color)]
            }
        }

        static let parts: [Reel.Part] = [
            part("a", frames: 3, Picture.Color(red: 0.8, green: 0.2, blue: 0.1)),
            part("empty", frames: 0, .white),
            part("b", frames: 5, Picture.Color(red: 0.1, green: 0.6, blue: 0.3)),
            part("a", frames: 2, Picture.Color(red: 0.2, green: 0.3, blue: 0.9)),
        ]

        /// A bar over the frames 4 up to 7 of the reel, moving with the reel's frame.
        static func layer(at rate: Rate) -> Reel.Layer {
            Reel.Layer("bar", over: rate.start(of: 4)..<rate.start(of: 7)) { frame in
                [Tests.rectangle(Double(Int(bitPattern: frame.position)), 10, 3, 3, Picture.Color(red: 1, green: 1, blue: 0.2, alpha: 0.7))]
            }
        }

        static func reel(at rate: Rate = .ntsc, layered: Bool = false) -> Reel {
            Reel(
                width: width,
                height: height,
                rate: rate,
                over: Picture.Color(gray: 0.5),
                parts: parts,
                layers: layered ? [layer(at: rate)] : []
            )
        }

        static func png(_ raster: Raster<Picture.Pixel>) throws -> [Byte] {
            W3C_PNG::W3C_PNG.serialize(try W3C_PNG::W3C_PNG.Image(raster), level: .fast)
        }

        @Test func `a reel lasts the sum of its parts' frames`() {
            #expect(Self.reel().frames == 10)
            #expect(Reel(width: 1, height: 1, rate: .thirty, parts: []).frames == 0)
        }

        @Test func `each frame falls in its part, at the part's own frame, across every cut and at any rate`() {
            for rate in [Rate.ntsc, .film, .thirty] {
                let reel = Self.reel(at: rate)
                let expected: [(part: Ordinal, key: String, frame: Ordinal)] = [
                    (0, "a", 0), (0, "a", 1), (0, "a", 2),
                    (2, "b", 0), (2, "b", 1), (2, "b", 2), (2, "b", 3), (2, "b", 4),
                    (3, "a", 0), (3, "a", 1),
                ]
                for (position, place) in expected.enumerated() {
                    #expect(reel.place(of: Ordinal(UInt(position))) == Reel.Place(part: place.part, key: place.key, frame: place.frame))
                }
                #expect(reel.place(of: 10) == nil)
                #expect(reel.place(of: 1000) == nil)
            }
        }

        @Test func `the positions of keys are every part with each key, the keys in the order given`() {
            let reel = Self.reel()
            #expect(reel.positions(of: ["b"]) == [3, 4, 5, 6, 7])
            #expect(reel.positions(of: ["a"]) == [0, 1, 2, 8, 9])
            #expect(reel.positions(of: ["b", "a"]) == [3, 4, 5, 6, 7, 0, 1, 2, 8, 9])
            #expect(reel.positions(of: ["empty", "none"]).isEmpty)
            #expect(reel.positions() == (0..<10).map { Ordinal(UInt($0)) })
        }

        @Test func `an instant of chosen parts is the reel's instant of its frame, at the same offset into it`() throws {
            let reel = Self.reel()
            let rate = reel.rate
            let quarter = rate.period * (try Rational(numerator: 1, denominator: 4))
            #expect(reel.instants([.zero, rate.start(of: 2) + quarter], of: ["b"]) == [rate.start(of: 3), rate.start(of: 5) + quarter])
            #expect(reel.instants([rate.start(of: 5), rate.start(of: 8)], of: ["b", "a"]) == [rate.start(of: 0), rate.start(of: 8)])
            #expect(reel.instants([rate.start(of: 5)], of: ["b"]) == [rate.start(of: 5)])
            #expect(reel.instants([quarter, rate.start(of: 7)], of: nil) == [quarter, rate.start(of: 7)])
        }

        @Test func `a layer is laid over the frames whose center falls in its lifetime, and over no other`() throws {
            let reel = Self.reel(layered: true)
            let counts = try reel.positions().map { try reel.picture(at: $0).elements.count }
            #expect(counts == [1, 1, 1, 1, 2, 2, 2, 1, 1, 1])
            let plain = Self.reel()
            #expect(try reel.picture(at: 3) == plain.picture(at: 3))
            #expect(try reel.picture(at: 7) == plain.picture(at: 7))
            var expected = try plain.picture(at: 5)
            expected.elements.append(contentsOf: Self.layer(at: .ntsc).timeline.content(Reel.Frame(position: 5, time: Rate.ntsc.centre(of: 5))).elements)
            #expect(try reel.picture(at: 5) == expected)
            #expect(try reel.picture(at: 10) == .empty)
        }

        @Test func `a reel's frames are its parts' own pictures drawn one by one, and a part chosen alone keeps its layers`() async throws {
            let reel = Self.reel()
            let expected = try Self.parts.flatMap { part in
                try (0..<Int(clamping: part.frames)).map { local in
                    let frame = Reel.Frame(position: Ordinal(UInt(local)), time: Rate.ntsc.centre(of: Integer(local)))
                    return try Motion.Hosting.Picture.raster(part.picture(frame), width: Self.width, height: Self.height, over: reel.background)
                }
            }
            #expect(try await reel.hosting(workers: 3).rasters(reel.positions()) == expected)
            let layered = Self.reel(layered: true)
            let chosen = try await layered.hosting(["b"], workers: 2).rasters([0, 1, 2, 3, 4])
            let whole = try await layered.hosting(workers: 2).rasters([3, 4, 5, 6, 7])
            #expect(chosen == whole)
            let background = Raster(width: Self.width, height: Self.height, repeating: Motion.Pixel(Picture.Color(gray: 0.5).pixel))
            #expect(try await layered.hosting(["b"], workers: 1).rasters([5]) == [background])
        }

        /// A triangle through three points, filled with a colour: slanted edges, whose pixels are only partly covered.
        static func triangle(_ points: [(Double, Double)], _ color: Picture.Color) -> Picture.Element {
            let corners = points.map { Picture.Plane.Point<2>([$0.0, $0.1]) }
            let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { start, end in
                Picture.Plane.Path.Segment.line(.init(start: start, end: end))
            }
            let path = Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
            return .shape(Picture.Shape(path, fill: .init(.solid(color))))
        }

        @Test func `a reel at scale one is the reel, frame for frame`() async throws {
            let reel = Self.reel(layered: true)
            let same = reel.scaled(by: 1)
            #expect(same.width == reel.width && same.height == reel.height && same.scale == 1)
            #expect(try await same.hosting(workers: 2).rasters(reel.positions()) == reel.hosting(workers: 2).rasters(reel.positions()))
        }

        @Test func `a draft at half the scale is half as wide and high and close to the full frame made smaller`() async throws {
            let full = Reel(
                width: 96,
                height: 64,
                rate: .thirty,
                over: Picture.Color(gray: 0.5),
                parts: [
                    Reel.Part("shapes", frames: 3) { frame in
                        let shift = Double(Int(bitPattern: frame.position)) * 3.3
                        return [
                            Tests.rectangle(7.3 + shift, 5.6, 41.7, 23.1, Picture.Color(red: 0.8, green: 0.2, blue: 0.1)),
                            Tests.rectangle(30.2, 20.9 + shift, 50.5, 31.4, Picture.Color(red: 0.1, green: 0.6, blue: 0.9, alpha: 0.6)),
                            Self.triangle([(4.4 + shift, 60.1), (52.7, 3.3 + shift), (90.9, 41.6)], .white),
                        ]
                    }
                ],
                layers: [Reel.Layer("bar", over: 0..<1) { _ in [Tests.rectangle(3.1, 48.2, 80.4, 9.7, .white)] }]
            )
            let draft = full.scaled(by: 0.5)
            #expect(draft.width == 48 && draft.height == 32 && draft.scale == 0.5)
            let large = try await full.hosting(workers: 1).drawn(full.positions()) { _, raster in
                raster.resampled(width: 48, height: 32, .box) { (from: Picture.Pixel, to: Picture.Pixel, parameter: Float) in
                    from.interpolated(to: to, at: parameter)
                }.map { Motion.Pixel($0) }
            }
            let small = try await draft.hosting(workers: 1).rasters(draft.positions())
            for (made, drawn) in zip(large, small) {
                let psnr = try #require(drawn.psnr(against: made))
                #expect(psnr > 40)
            }
            #expect(Reel(width: 3, height: 1, rate: .thirty, parts: []).scaled(by: 0.5).width == 2)
            #expect(Reel(width: 1, height: 1, rate: .thirty, parts: []).scaled(by: 0.1).width == 1)
        }

        @Test func `a scene is a part drawn from its state at each frame's center`() throws {
            let scene = Motion.Scene(rate: .thirty, frames: 4) { time in time < Rate.thirty.start(of: 3) ? 0 : 1 }
            let part = Reel.Part("scene", scene: scene) { state in state == 0 ? .empty : [Tests.rectangle(0, 0, 1, 1, .white)] }
            #expect(part.frames == 4)
            let counts = try (0..<4).map { local in try part.picture(Reel.Frame(position: Ordinal(UInt(local)), time: .zero)).elements.count }
            #expect(counts == [0, 0, 0, 1])
        }

        @Test func `a printed sheet is the frames' sheet, and a still the frame at full size, each as a PNG, every frame drawn once`() async throws {
            let reel = Self.reel(layered: true)
            let sheet = Reel.Sheet("cut", frames: [2, 3, 4, 5, 9], columns: 2, gap: 1, fill: .white)
            let proof = Reel.Proof(sheets: [sheet, Reel.Sheet(frames: [0, 9], columns: 3)], stills: [5, 0])
            let prints = try await reel.prints(proof, workers: 3)
            let frames = reel.hosting(workers: 1)
            #expect(prints.sheets["cut"] == (try Self.png(try await frames.sheet([2, 3, 4, 5, 9], columns: 2, gap: 1, fill: .white))))
            #expect(prints.sheets[""] == (try Self.png(try await frames.sheet([0, 9], columns: 3, gap: 12, fill: Picture.Color(gray: 0.12)))))
            let full = try await frames.drawn([5, 0]) { _, raster in raster }
            #expect(prints.stills[5] == (try Self.png(full[0])))
            #expect(prints.stills[0] == (try Self.png(full[1])))
            #expect(prints.stills.count == 2)
            let part = try await reel.prints(Reel.Proof(stills: [1]), of: ["b"])
            let fourth = try await frames.drawn([4]) { _, raster in raster }
            #expect(part.stills[1] == (try Self.png(fourth[0])))
        }

        @Test func `a proof that asks for a frame beyond the frames printed fails before drawing`() async {
            await #expect(throws: Reel.Error.outside(5)) {
                try await Self.reel().prints(Reel.Proof(stills: [5]), of: ["b"])
            }
            await #expect(throws: Reel.Error.outside(10)) {
                try await Self.reel().prints(Reel.Proof(sheets: [Reel.Sheet(frames: [10], columns: 1)]))
            }
        }

        @Test func `an overview is one sheet of at most sixty frames, ten to a row, and the first, middle and last frames`() {
            #expect(Reel.Proof.overview(of: 0) == Reel.Proof())
            #expect(Reel.Proof.overview(of: 1) == Reel.Proof(sheets: [Reel.Sheet(frames: [0], columns: 10)], stills: [0]))
            let ten = Reel.Proof.overview(of: 10)
            #expect(ten.sheets.map(\.frames) == [(0..<10).map { Ordinal(UInt($0)) }])
            #expect(ten.stills == [0, 5, 9])
            let long = Reel.Proof.overview(of: 130)
            #expect(long.sheets[0].frames.count == 44)
            #expect(long.sheets[0].frames.prefix(3) == [0, 3, 6])
            #expect(Reel.Proof.overview(of: 600).sheets[0].frames.count == 60)
        }

        @Test func `the numbered sequence and the movie's feed give every chosen frame in order, then nil`() async throws {
            let reel = Self.reel()
            let sequence = reel.sequence(["b"], workers: 2)
            let whole = try await reel.hosting(workers: 1).drawn([3, 4, 5, 6, 7]) { _, raster in raster }
            for (local, raster) in whole.enumerated() {
                #expect(try await sequence.frame(at: Ordinal(UInt(local)))?.get() == (try Self.png(raster)))
            }
            #expect(try await sequence.frame(at: 5) == nil)
            let movie = reel.movie(["a"], workers: 2)
            #expect(movie.frames == 5)
            #expect(try await movie.feed.frame(at: 3) == (try await reel.hosting(workers: 1).rasters([8]))[0])
            #expect(try await movie.feed.frame(at: 5) == nil)
        }

        @Test func `a layer's frames are those whose center falls in its lifetime, and a reel can drop its layers`() async throws {
            let reel = Self.reel(layered: true)
            #expect(reel.positions(ofLayer: "bar") == [4, 5, 6])
            #expect(reel.positions(ofLayer: "none") == [])
            let tick = try Rational(numerator: 1, denominator: 100_000)
            #expect(reel.positions(during: reel.rate.centre(of: 2)..<reel.rate.centre(of: 4)) == [2, 3])
            #expect(reel.positions(during: (reel.rate.centre(of: 2) + tick)..<(reel.rate.centre(of: 4) + tick)) == [3, 4])
            #expect(reel.positions(during: 0..<1000) == (0..<10).map { Ordinal(UInt($0)) })
            let bare = reel.layered([])
            #expect(bare.layers.isEmpty)
            #expect(reel.layered(["bar"]).layers.count == 1)
            let plain = try await Self.reel().hosting(workers: 1).rasters([5])
            #expect(try await bare.hosting(workers: 1).rasters([5]) == plain)
            #expect(try await reel.hosting(workers: 1).rasters([5]) != plain)
        }

        @Test func `a proof prints pictures that are no frame alone at the reel's size, and overviews any frames`() async throws {
            let reel = Self.reel()
            let alone: Picture = [Tests.rectangle(2, 2, 4, 4, .white)]
            let proof = Reel.Proof(pictures: ["badge": alone])
            let prints = try await reel.prints(proof)
            let drawn = Motion.Hosting.Picture.Frames(width: Self.width, height: Self.height, over: Picture.Color(gray: 0.5), workers: 1) { _ in alone }
            let expected = try await drawn.drawn([0]) { _, raster in raster }
            #expect(prints.pictures["badge"] == (try Self.png(expected[0])))
            let some = Reel.Proof.overview(of: [4, 5, 6] as [Ordinal])
            #expect(some == Reel.Proof(sheets: [Reel.Sheet(frames: [4, 5, 6], columns: 10)], stills: [4, 5, 6]))
        }
        @Test func `asking for frames of one part builds that part's drawing once and no other part's`() async throws {
            let built = Mutex<[String: Int]>([:])
            func part(_ key: String, frames: Cardinal) -> Reel.Part {
                Reel.Part(key, frames: frames) {
                    built.withLock { $0[key, default: 0] += 1 }
                    return { frame in [Tests.rectangle(Double(Int(bitPattern: frame.position)), 2, 5, 6, .white)] }
                }
            }
            let reel = Reel(width: Self.width, height: Self.height, rate: .ntsc, parts: [part("a", frames: 3), part("b", frames: 4), part("c", frames: 2)])
            #expect(reel.frames == 9)
            #expect(reel.place(of: 5)?.key == "b")
            #expect(reel.positions(of: ["b"]) == [3, 4, 5, 6])
            #expect(built.withLock { $0 }.isEmpty)
            let frames = try await reel.hosting(["b"], workers: 3).rasters([0, 1, 2, 3])
            #expect(frames.count == 4)
            #expect(built.withLock { $0 } == ["b": 1])
            _ = try reel.picture(at: 1)
            _ = try reel.picture(at: 2)
            #expect(built.withLock { $0 } == ["a": 1, "b": 1])
        }

        @Test func `a scene's part built on demand draws as the scene's part drawn at once`() throws {
            let scene = Motion.Scene(rate: .thirty, frames: 4) { time in time < Rate.thirty.start(of: 3) ? 0 : 1 }
            let drawing: @Sendable (Int) -> Picture = { state in state == 0 ? .empty : [Tests.rectangle(0, 0, 1, 1, .white)] }
            let ready = Reel.Part("scene", scene: scene, picture: drawing)
            let later = Reel.Part("scene", scene: scene, building: { drawing })
            let frames = (0..<4).map { Reel.Frame(position: Ordinal(UInt($0)), time: .zero) }
            #expect(try frames.map { try ready.picture($0) } == frames.map { try later.picture($0) })
        }

        @Test func `a part whose building fails fails the reel's drawing with its key and that failure, built once`() async throws {
            let built = Mutex(0)
            let failing = Reel.Part("broken", frames: 2) { () throws(Typesetting.Error) in
                built.withLock { $0 += 1 }
                throw .size
            }
            let reel = Reel(width: Self.width, height: Self.height, rate: .ntsc, parts: [Self.part("a", frames: 2, .white), failing])
            #expect(throws: Reel.Error.building("broken", .size)) { try reel.picture(at: 2) }
            #expect(throws: Reel.Error.building("broken", .size)) { try reel.picture(at: 3) }
            #expect(built.withLock { $0 } == 1)
            #expect(try reel.picture(at: 1) != .empty)
            await #expect(throws: Motion.Hosting.Picture.Frames.Error.building(.size, at: 1)) {
                try await reel.hosting(["broken"], workers: 1).rasters([1])
            }
            await #expect(throws: Reel.Error.building("broken", .size)) {
                try await reel.prints(Reel.Proof(stills: [3]))
            }
            #expect(reel.failure(.building(.size, at: 1), of: ["broken"]) == .building("broken", .size))
            #expect(built.withLock { $0 } == 1)
        }
    }
#endif
