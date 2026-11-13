#if Command
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

        static let reel = Reel(
            width: 20,
            height: 12,
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
            #expect(movie.width == 20)
            #expect(movie.height == 12)
        }

        @Test func `compare sets a movie beside the reel drawn directly, every step, pairs to a sheet`() async throws {
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
            let score = try Movies.parse(["score", "a.mp4", "s.mp3", "b.mp4", "--offset", "1001/30000", "--at", "1", "--gain", "0.5", "--fade-out", ".5"])
            #expect(score.offset == (try Rational(numerator: 1001, denominator: 30000)) && score.at == 1 && score.gain == 0.5)
            #expect(score.fadeOut == Request.half)
            #expect(try Movies.parse(["reduce", "a.mp4", "b.mp4", "--height", "540"]).preset == .height540)
            #expect(throws: Command.Error.self) { try Movies.parse(["score", "a.mp4", "b.mp4"]) }
            #expect(throws: Command.Error.self) { try Movies.parse(["reduce", "a.mp4", "b.mp4", "--height", "600"]) }
            #expect(throws: Command.Error.self) { try Movies.parse(["compare", "a", "b", "c", "--step", "-1"]) }
            #expect(throws: Command.Error.self) { try Movies.parse(["compare", "a", "b", "c", "--step", "x.5"]) }
            #expect(Movies.help.contains("--fade-in"))
        }

        @Test func `compare over movie files writes sheets until the longer movie ends, and score replaces its output`() async throws {
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
