#if Command
    import AVFoundation
    import Command
    import File_System
    import Motion
    import Motion_Command
    import Motion_Encoding
    import Foundation
    import Motion_Picture
    import Picture
    import Testing

    @Suite struct `Command Tests` {
        typealias Request = Motion.Command.Request
        typealias Reel = Motion.Reel<Swift.String>

        /// A dot laid over the first two frames of the reel.
        static let dot = Reel.Layer("dot", over: 0..<Rate.thirty.start(of: 2)) { _ in [square(10)] }

        /// The smallest reel whose draft at half size is still a movie `Motion.Encoding` writes.
        static let reel = Reel(
            width: 32,
            height: 32,
            rate: .thirty,
            over: .white,
            parts: [
                Reel.Part("opening", frames: 4) { frame in
                    [square(Double(Int(bitPattern: frame.position)))]
                },
                Reel.Part("ending", frames: 3) { _ in .empty },
            ],
            layers: [dot]
        )

        /// A black square four pixels on a side, one row down and `x` across.
        static func square(_ x: Double) -> Picture.Element {
            let corners: [Picture.Plane.Point<2>] = [.init([x, 1]), .init([x + 4, 1]), .init([x + 4, 5]), .init([x, 5])]
            let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { start, end in
                Picture.Plane.Path.Segment.line(.init(start: start, end: end))
            }
            let path = Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
            return .shape(Picture.Shape(path, fill: .init(.solid(.black))))
        }

        /// A directory of its own under the system's temporary directory.
        static func directory() -> Swift.String {
            "/tmp/motion-command-tests-" + Swift.String(UInt64.random(in: 0...UInt64.max))
        }

        /// Every file a run wrote, read back in the order written.
        static func contents(_ files: [Swift.String]) throws -> [[Byte]] {
            try files.map { try File(File.Path(validating: $0)).read.bytes() }
        }

        @Test func `a cache directory and a scale are read from the command line`() throws {
            let request = try Request.parse(["frames", "out", "--cache", "/tmp/kept", "--scale", "0.5"])
            #expect(request.cache == "/tmp/kept" && request.scale == 0.5)
            #expect(try Request.parse(["frames", "out"]).cache.isEmpty)
            #expect(try Request.parse(["frames", "out"]).scale == 1)
            #expect(throws: Command.Error.self) { try Request.parse(["frames", "out", "--scale", "0"]) }
            #expect(throws: Command.Error.self) { try Request.parse(["frames", "out", "--scale", "half"]) }
        }

        @Test(.timeLimit(.minutes(1))) func `a run through a warm cache writes the bytes a run without one writes`() async throws {
            let directory = Self.directory()
            let cache = directory + "/cache"
            let proof = Reel.Proof(sheets: [Reel.Sheet("start", frames: [0, 1, 2], columns: 2)], stills: [3], pictures: ["square": [Self.square(3)]])
            let film = Motion.Command.Film(Self.reel, parts: ["opening": proof])
            for action in [Motion.Command.Action.sheet, .frames] {
                let plain = try await Motion.Command.run(film, Request(action, output: directory + "/plain-\(action)"))
                let cold = try await Motion.Command.run(film, Request(action, output: directory + "/cold-\(action)", cache: cache))
                let warm = try await Motion.Command.run(film, Request(action, output: directory + "/warm-\(action)", cache: cache))
                #expect(try Self.contents(cold) == Self.contents(plain))
                #expect(try Self.contents(warm) == Self.contents(plain))
            }
            let plain = try await Motion.Command.run(Self.reel, Request(.movie, output: directory + "/plain"))
            let again = try await Motion.Command.run(Self.reel, Request(.movie, output: directory + "/again"))
            let cold = try await Motion.Command.run(Self.reel, Request(.movie, output: directory + "/cold", cache: cache))
            let warm = try await Motion.Command.run(Self.reel, Request(.movie, output: directory + "/warm", cache: cache))
            // AVFoundation's writer does not write the same bytes twice for the same frames, so a movie is held
            // to its frames: two uncached runs differ in bytes as a warm run does.
            #expect(try Self.contents(again) != Self.contents(plain))
            #expect(try await Self.decoded(again[0]) == Self.decoded(plain[0]))
            #expect(try await Self.decoded(cold[0]) == Self.decoded(plain[0]))
            #expect(try await Self.decoded(warm[0]) == Self.decoded(plain[0]))
        }

        @Test(.timeLimit(.minutes(1))) func `compare through a warm cache writes the sheets compare writes without one`() async throws {
            let directory = Self.directory()
            let cache = directory + "/cache"
            _ = try await Motion.Command.run(Self.reel, Request(.movie, output: directory))
            let tenth = try Rational(numerator: 1, denominator: 10)
            func compare(_ name: Swift.String, cache: Swift.String = "") async throws -> [Swift.String] {
                let request = Request(.compare, output: directory + "/" + name, reference: directory + "/reel.mp4", step: tenth, pairs: 2, width: 10, cache: cache)
                return try await Motion.Command.run(Self.reel, request)
            }
            let plain = try await compare("plain")
            let cold = try await compare("cold", cache: cache)
            let warm = try await compare("warm", cache: cache)
            #expect(!plain.isEmpty)
            #expect(try Self.contents(cold) == Self.contents(plain))
            #expect(try Self.contents(warm) == Self.contents(plain))
        }

        /// Every frame of a movie, decoded.
        static func decoded(_ file: Swift.String) async throws -> [Raster<Motion.Pixel>] {
            let box = Frames()
            _ = try await Motion.Encoding.read(URL(filePath: file)) { _, raster in box.append(raster) }
            return box.frames
        }

        final class Frames: @unchecked Sendable {
            var frames: [Raster<Motion.Pixel>] = []
            func append(_ raster: Raster<Motion.Pixel>) { frames.append(raster) }
        }

        @Test func `a changed reel through a warm cache writes what it draws, never what was kept`() async throws {
            let directory = Self.directory()
            let cache = directory + "/cache"
            _ = try await Motion.Command.run(Self.reel, Request(.frames, output: directory + "/first", cache: cache))
            let changed = Reel(
                width: 32,
                height: 32,
                rate: .thirty,
                over: .white,
                parts: [Reel.Part("opening", frames: 4) { frame in [Self.square(Double(Int(bitPattern: frame.position)) + 0.5)] }],
                layers: [Self.dot]
            )
            let plain = try await Motion.Command.run(changed, Request(.frames, output: directory + "/plain"))
            let warm = try await Motion.Command.run(changed, Request(.frames, output: directory + "/warm", cache: cache))
            #expect(try Self.contents(warm) == Self.contents(plain))
            let first = try Self.contents((0..<4).map { directory + "/first/0000\($0).png" })
            #expect(try first != Self.contents(plain))
        }

        @Test func `a draft is the reel at a scale, kept apart from its full size in one cache`() async throws {
            let directory = Self.directory()
            let cache = directory + "/cache"
            _ = try await Motion.Command.run(Self.reel, Request(.frames, output: directory + "/full", cache: cache))
            let plain = try await Motion.Command.run(Self.reel, Request(.frames, output: directory + "/plain", scale: 0.5))
            let warm = try await Motion.Command.run(Self.reel, Request(.frames, output: directory + "/warm", cache: cache, scale: 0.5))
            #expect(try Self.contents(warm) == Self.contents(plain))
            let movie = try await Motion.Command.run(Self.reel, Request(.movie, output: directory, scale: 0.5))
            let inspection = try await Motion.Encoding.Inspection(of: URL(filePath: movie[0]))
            #expect(inspection.width == 16 && inspection.height == 16)
        }

        @Test func `an action and a directory are all a request needs`() throws {
            #expect(try Request.parse(["frames", "out"]) == Request(.frames, output: "out"))
            #expect(try Request.parse(["movie", "/a/b"]) == Request(.movie, output: "/a/b"))
            #expect(try Request.parse(["sheet", "out"]).columns == 5)
        }

        @Test func `parts are given one by one or joined by commas, in order, and frames with commas`() throws {
            let arguments = ["sheet", "out", "--part", "ending,opening", "--part", "middle", "--at", "0,3,12", "--stills", "7", "--columns", "4"]
            let request = try Request.parse(arguments)
            #expect(request == Request(.sheet, output: "out", parts: ["ending", "opening", "middle"], at: [0, 3, 12], stills: [7], columns: 4))
        }

        @Test func `an unknown action, a frame that is no number, no columns and a missing directory are refused`() {
            #expect(throws: Command.Error.self) { try Request.parse(["print", "out"]) }
            #expect(throws: Command.Error.self) { try Request.parse(["sheet", "out", "--at", "1,x"]) }
            #expect(throws: Command.Error.self) { try Request.parse(["sheet", "out", "--columns", "0"]) }
            #expect(throws: Command.Error.self) { try Request.parse(["sheet"]) }
            #expect(throws: Command.Error.helpRequested) { try Request.parse(["--help"]) }
            #expect(Request.help.contains("--part"))
        }

        @Test func `a part no reel has is refused before anything is written`() async {
            let directory = Self.directory()
            await #expect {
                try await Motion.Command.run(Self.reel, Request(.sheet, output: directory, parts: ["middle"]))
            } throws: { error in
                guard let error = error as? Motion.Command.Error, case .part(let name) = error else { return false }
                return name == "middle"
            }
            #expect(throws: File.System.Read.Full.Error.self) { try File(File.Path(validating: directory)).read.bytes() }
        }

        @Test func `sheet writes each part's proof, or one sheet of the chosen frames, as the reel prints them`() async throws {
            let directory = Self.directory()
            let proof = Reel.Proof(sheets: [Reel.Sheet("start", frames: [0, 1], columns: 2)], stills: [3])
            let written = try await Motion.Command.run(Self.reel, Request(.sheet, output: directory), proofs: ["opening": proof])
            let names = ["sheet-opening-start", "opening-00003", "sheet-ending", "ending-00000", "ending-00001", "ending-00002"]
            #expect(written == names.map { directory + "/" + $0 + ".png" })
            let prints = try await Self.reel.prints(proof, of: ["opening"])
            #expect(try File(File.Path(validating: written[0])).read.bytes() == prints.sheets["start"])
            #expect(try File(File.Path(validating: written[1])).read.bytes() == prints.stills[3])
            let request = Request(.sheet, output: directory, parts: ["ending", "opening"], at: [0, 4], stills: [6])
            let chosen = try await Motion.Command.run(Self.reel, request)
            #expect(chosen == [directory + "/sheet-ending+opening-at.png", directory + "/ending+opening-00006.png"])
            let asked = Reel.Proof(sheets: [Reel.Sheet("at", frames: [0, 4], columns: 5)], stills: [6])
            let at = try await Self.reel.prints(asked, of: ["ending", "opening"])
            #expect(try File(File.Path(validating: chosen[0])).read.bytes() == at.sheets["at"])
        }

        @Test func `frames writes every chosen frame, numbered from zero`() async throws {
            let directory = Self.directory()
            let written = try await Motion.Command.run(Self.reel, Request(.frames, output: directory, parts: ["ending"]))
            #expect(written == (0..<3).map { directory + "/0000\($0).png" })
        }

        @Test func `movie writes every chosen frame as a movie at the reel's size and rate, replacing one there`() async throws {
            let directory = Self.directory()
            let request = Request(.movie, output: directory, parts: ["opening", "ending"])
            #expect(try await Motion.Command.run(Self.reel, request) == [directory + "/opening+ending.mp4"])
            #expect(try await Motion.Command.run(Self.reel, request) == [directory + "/opening+ending.mp4"])
            let movie = try await Motion.Encoding.Inspection(of: URL(filePath: directory + "/opening+ending.mp4"))
            #expect(movie.frames == 7)
            #expect(movie.width == 32)
            #expect(movie.height == 32)
        }

        /// A second of silence at 48 kHz, written as AAC into `directory`.
        static func sound(in directory: Swift.String) throws -> Swift.String {
            let file = directory + "/sound.m4a"
            let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000))
            buffer.frameLength = 48_000
            let settings: [Swift.String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2]
            let written = try AVAudioFile(forWriting: URL(filePath: file), settings: settings)
            try written.write(from: buffer)
            written.close()
            return file
        }

        @Test func `a sound and its level and fades are read for movie, and refused for any other action`() throws {
            let request = try Request.parse(["movie", "out", "--sound", "s.m4a", "--offset", "2", "--gain", "0.32", "--fade-in", "1", "--fade-out", "3"])
            #expect(request == Request(.movie, output: "out", sound: "s.m4a", offset: 2, gain: 0.32, rise: 1, fall: 3))
            #expect(try Request.parse(["movie", "out"]).sound.isEmpty)
            #expect(throws: Command.Error.self) { try Request.parse(["sheet", "out", "--sound", "s.m4a"]) }
            #expect(throws: Command.Error.self) { try Request.parse(["movie", "out", "--sound", "s.m4a", "--gain", "-1"]) }
            #expect(Request.help.contains("--sound"))
        }

        @Test(.timeLimit(.minutes(1))) func `movie with a sound writes the movie with the sound under it in the same run, replacing one there`() async throws {
            let directory = Self.directory()
            try File.Directory(File.Path(validating: directory)).create.recursive()
            let request = Request(.movie, output: directory, sound: try Self.sound(in: directory), gain: 0.32, fall: .half)
            #expect(try await Motion.Command.run(Self.reel, request) == [directory + "/reel.mp4"])
            #expect(try await Motion.Command.run(Self.reel, request) == [directory + "/reel.mp4"])
            let movie = try await Motion.Encoding.Inspection(of: URL(filePath: directory + "/reel.mp4"))
            #expect(movie.frames == 7 && movie.width == 32 && movie.height == 32 && movie.sounds == 1)
            #expect(try FileManager.default.contentsOfDirectory(atPath: directory).sorted() == ["reel.mp4", "sound.m4a"])
        }

        @Test(.timeLimit(.minutes(1))) func `compare sets a movie beside the reel drawn directly, every step, pairs to a sheet`() async throws {
            let directory = Self.directory()
            _ = try await Motion.Command.run(Self.reel, Request(.movie, output: directory))
            let tenth = try Rational(numerator: 1, denominator: 10)
            let request = Request(.compare, output: directory + "/compare", reference: directory + "/reel.mp4", step: tenth, pairs: 1, width: 10)
            let written = try await Motion.Command.run(Self.reel, request)
            #expect(written == (0..<3).map { directory + "/compare/pairs-0000\($0).png" })
            #expect(throws: Command.Error.self) { try Request.parse(["compare", "out"]) }
            #expect(try Request.parse(["compare", "out", "--reference", "a.mp4", "--step", "0.25"]).step == Rational(numerator: 1, denominator: 4))
        }

        @Test func `a request over movie files takes its files and options, and seconds as decimals or fractions`() throws {
            typealias Movies = Motion.Command.Movies
            let compare = try Movies.parse(["compare", "a.mp4", "b.mp4", "out", "--step", "1.5", "--pairs", "4", "--font", "f.ttf"])
            #expect(compare == Movies(.compare, files: ["a.mp4", "b.mp4", "out"], step: try Rational(numerator: 3, denominator: 2), pairs: 4, font: "f.ttf"))
            let score = try Movies.parse(["score", "a.mp4", "s.mp3", "b.mp4", "--offset", "1001/30000", "--at", "1", "--gain", "0.5", "--fade-out", "0.5"])
            #expect(score.offset == (try Rational(numerator: 1001, denominator: 30000)) && score.at == 1 && score.gain == 0.5)
            #expect(score.fall == .half)
            #expect(try Movies.parse(["reduce", "a.mp4", "b.mp4", "--height", "540"]).preset == .height540)
            #expect(try Movies.parse(["reduce", "a.mp4", "b.mp4", "--bytes", "1000000"]).bytes == 1_000_000)
            #expect(try Movies.parse(["reduce", "a.mp4", "b.mp4"]).bytes == nil)
            #expect(throws: Command.Error.self) { try Movies.parse(["score", "a.mp4", "b.mp4"]) }
            #expect(throws: Command.Error.self) { try Movies.parse(["reduce", "a.mp4", "b.mp4", "--height", "600"]) }
            #expect(throws: Command.Error.self) { try Movies.parse(["compare", "a", "b", "c", "--step", "-1"]) }
            #expect(throws: Command.Error.self) { try Movies.parse(["compare", "a", "b", "c", "--step", "x.5"]) }
            #expect(Movies.help.contains("--fade-in"))
        }

        @Test(.timeLimit(.minutes(1))) func `compare over movie files writes sheets until the longer movie ends, and score replaces its output`() async throws {
            let directory = Self.directory()
            _ = try await Motion.Command.run(Self.reel, Request(.movie, output: directory))
            _ = try await Motion.Command.run(Self.reel, Request(.movie, output: directory, parts: ["opening"]))
            let movies = Motion.Command.Movies(
                .compare,
                files: [directory + "/reel.mp4", directory + "/opening.mp4", directory + "/compare"],
                step: try Rational(numerator: 1, denominator: 15),
                pairs: 2,
                width: 10
            )
            let written = try await Motion.Command.run(movies)
            #expect(written == (0..<2).map { directory + "/compare/pairs-0000\($0).png" })
        }

        @Test func `layers, proofs and settings are read from the command line`() throws {
            let request = try Request.parse(["sheet", "out", "--layer", "dot,glow", "--proof", "dots", "--bare", "--set", "assets=/a/b", "--set", "x=1=2"])
            #expect(request.layers == ["dot", "glow"] && request.proofs == ["dots"] && request.bare)
            #expect(request.value("assets") == "/a/b" && request.value("x") == "1=2" && request.value("y") == nil)
            #expect(throws: Command.Error.self) { try Request.parse(["sheet", "out", "--set", "assets"]) }
        }

        @Test func `a reel is drawn with the layers named, or none, and an unknown layer is refused`() async throws {
            let directory = Self.directory()
            let layered = try await Motion.Command.run(Self.reel, Request(.frames, output: directory + "/layered", parts: ["opening"]))
            let bare = try await Motion.Command.run(Self.reel, Request(.frames, output: directory + "/bare", parts: ["opening"], bare: true))
            let named = try await Motion.Command.run(Self.reel, Request(.frames, output: directory + "/named", parts: ["opening"], layers: ["dot"]))
            let read = { (file: Swift.String) throws -> [Byte] in try File(File.Path(validating: file)).read.bytes() }
            #expect(try read(layered[0]) != read(bare[0]))
            #expect(try read(layered[0]) == read(named[0]))
            #expect(try read(layered[3]) == read(bare[3]))
            await #expect {
                try await Motion.Command.run(Self.reel, Request(.frames, output: directory, layers: ["glow"]))
            } throws: { error in
                guard let error = error as? Motion.Command.Error, case .layer(let name) = error else { return false }
                return name == "glow"
            }
        }

        @Test func `a film's proofs of the whole reel are written by name, with their pictures, and an unknown one is refused`() async throws {
            let directory = Self.directory()
            let span = Reel.Proof.overview(of: Self.reel.positions(ofLayer: "dot"))
            let alone = Reel.Proof(pictures: ["square": [Self.square(0)]])
            let film = Motion.Command.Film(Self.reel, proofs: ["dot": span, "alone": alone])
            let named = try await Motion.Command.run(film, Request(.sheet, output: directory, proofs: ["dot"]))
            #expect(named == ["sheet-dot", "dot-00000", "dot-00001"].map { directory + "/" + $0 + ".png" })
            let all = try await Motion.Command.run(film, Request(.sheet, output: directory))
            #expect(all.suffix(4) == ["alone-square", "sheet-dot", "dot-00000", "dot-00001"].map { directory + "/" + $0 + ".png" })
            await #expect {
                try await Motion.Command.run(film, Request(.sheet, output: directory, proofs: ["glow"]))
            } throws: { error in
                guard let error = error as? Motion.Command.Error, case .proof(let name) = error else { return false }
                return name == "glow"
            }
        }
    }
#endif
