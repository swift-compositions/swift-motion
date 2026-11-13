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
            ]
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
            let request = try Request.parse(["sheet", "out", "--part", "ending,opening", "--part", "middle", "--at", "0,3,12", "--stills", "7", "--columns", "4"])
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
            #expect(written == [directory + "/sheet-opening-start.png", directory + "/opening-00003.png", directory + "/sheet-ending.png", directory + "/ending-00000.png", directory + "/ending-00001.png", directory + "/ending-00002.png"])
            let prints = try await Self.reel.prints(proof, of: ["opening"])
            #expect(try File(File.Path(validating: written[0])).read.bytes() == prints.sheets["start"])
            #expect(try File(File.Path(validating: written[1])).read.bytes() == prints.stills[3])
            let chosen = try await Motion.Command.run(Self.reel, Request(.sheet, output: directory, parts: ["ending", "opening"], at: [0, 4], stills: [6]))
            #expect(chosen == [directory + "/sheet-ending+opening-at.png", directory + "/ending+opening-00006.png"])
            let at = try await Self.reel.prints(Reel.Proof(sheets: [Reel.Sheet("at", frames: [0, 4], columns: 5)], stills: [6]), of: ["ending", "opening"])
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
    }
#endif
