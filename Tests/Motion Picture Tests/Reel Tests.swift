#if Picture
    import Motion
    import Motion_Picture
    import Picture
    import Picture_PNG_Integration
    import Test_Apple
    import Testing
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
        static func layer(at rate: Rate) -> Timeline.Layer<@Sendable (Reel.Frame) -> Picture> {
            Timeline.Layer(
                { frame in
                    [Tests.rectangle(Double(Int(bitPattern: frame.position)), 10, 3, 3, Picture.Color(red: 1, green: 1, blue: 0.2, alpha: 0.7))]
                },
                over: rate.start(of: 4)..<rate.start(of: 7)
            )
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

        @Test func `a layer is laid over the frames whose centre falls in its lifetime, and over no other`() {
            let reel = Self.reel(layered: true)
            let counts = reel.positions().map { reel.picture(at: $0).elements.count }
            #expect(counts == [1, 1, 1, 1, 2, 2, 2, 1, 1, 1])
            let plain = Self.reel()
            #expect(reel.picture(at: 3) == plain.picture(at: 3))
            #expect(reel.picture(at: 7) == plain.picture(at: 7))
            var expected = plain.picture(at: 5)
            expected.elements.append(contentsOf: Self.layer(at: .ntsc).content(Reel.Frame(position: 5, time: Rate.ntsc.centre(of: 5))).elements)
            #expect(reel.picture(at: 5) == expected)
            #expect(reel.picture(at: 10) == .empty)
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

        @Test func `a scene is a part drawn from its state at each frame's centre`() {
            let scene = Motion.Scene(rate: .thirty, frames: 4) { time in time < Rate.thirty.start(of: 3) ? 0 : 1 }
            let part = Reel.Part("scene", scene: scene) { state in state == 0 ? .empty : [Tests.rectangle(0, 0, 1, 1, .white)] }
            #expect(part.frames == 4)
            let counts = (0..<4).map { local in part.picture(Reel.Frame(position: Ordinal(UInt(local)), time: .zero)).elements.count }
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
    }
#endif
