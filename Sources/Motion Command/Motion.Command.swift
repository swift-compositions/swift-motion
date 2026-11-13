#if Command
    import Command
    import File_System
    public import Motion
    public import Motion_Picture
    import Process
    import Picture_PNG_Integration
    #if canImport(AVFoundation)
        internal import AVFoundation
        import Motion_Encoding
    #endif

    extension Motion {
        /// A film's command line: the executable a reel is written from calls `main(_:arguments:)` with its film,
        /// or `main(arguments:_:)` with a function that makes the film from the request, and nothing else. It
        /// reads the arguments, writes the files and the movie, and holds no drawing of its own.
        ///
        ///     reel sheet <output> [--part <key>...] [--proof <name>...] [--at <frames>] [--stills <frames>] [--columns <count>]
        ///     reel frames <output> [--part <key>...]
        ///     reel movie <output> [--part <key>...]
        ///     reel compare <output> --reference <movie> [--part <key>...] [--step <s>] [--pairs <count>] [--width <pixels>] [--font <file>]
        ///
        /// Every action also takes `--layer <key>...` to draw only those layers, `--bare` to draw none, and
        /// `--set <name>=<value>...` for the maker of the film. `movie` and `compare` need AVFoundation and exist
        /// only where it does. `main(arguments:)` is the command line over movie files, which needs no reel:
        /// `compare`, `score` and `reduce`, as `Motion.Command.Movies` reads them.
        public enum Command {}
    }

    extension Motion.Command {
        /// Reads the command line, writes what it asks for of the film, says how many files it wrote, and ends
        /// the process: with 0 when it wrote them, 0 after printing the help it was asked for, the arguments'
        /// own code when they could not be read, and 1 when the film could not be made or writing failed.
        public static func main<Key, Failure: Swift.Error>(
            arguments: [Swift.String]? = nil,
            _ film: (Request) async throws(Failure) -> Film<Key>
        ) async -> Never {
            let request: Request
            do throws(Command_Primitive::Command.Error) {
                request = try Request.parse(arguments ?? Array(CommandLine.arguments.dropFirst()))
            } catch {
                if case .helpRequested = error {
                    print(Request.help, terminator: "")
                } else {
                    print(Command_Primitive::Command.Diagnostic.message(for: error))
                }
                Process.Exit.normal(Command_Primitive::Command.Diagnostic.exitCode(for: error))
            }
            let made: Film<Key>
            do throws(Failure) {
                made = try await film(request)
            } catch {
                print("error: \(error)")
                Process.Exit.normal(1)
            }
            let clock = ContinuousClock()
            let began = clock.now
            do throws(Error) {
                let written = try await run(made, request)
                print("\(written.count) files written into \(request.output) in \(clock.now - began)")
                Process.Exit.normal(0)
            } catch {
                print("error: \(error)")
                Process.Exit.normal(1)
            }
        }

        /// `main(arguments:_:)` of a film made before the command line is read.
        public static func main<Key>(_ film: Film<Key>, arguments: [Swift.String]? = nil) async -> Never {
            await main(arguments: arguments) { _ in film }
        }

        /// `main(_:arguments:)` of a reel with proofs of its parts.
        public static func main<Key>(
            _ reel: Motion.Reel<Key>,
            proofs: [Key: Motion.Reel<Key>.Proof] = [:],
            arguments: [Swift.String]? = nil
        ) async -> Never {
            await main(Film(reel, parts: proofs), arguments: arguments)
        }

        /// `run(_:_:)` of a reel with proofs of its parts.
        public static func run<Key>(
            _ reel: Motion.Reel<Key>,
            _ request: Request,
            proofs: [Key: Motion.Reel<Key>.Proof] = [:]
        ) async throws(Error) -> [Swift.String] {
            try await run(Film(reel, parts: proofs), request)
        }

        /// Writes what a request asks for of the reel into its output directory, made if it is not there, and
        /// gives the paths written, in the order written.
        ///
        /// The frames are those of the parts the request names, by `String(describing:)` of their keys, played
        /// one after another, or every frame of the reel. `sheet` with frames `at` or `stills` writes one sheet
        /// of the frames `at`, `columns` to a row, as `sheet-<parts>-at.png` and the stills as
        /// `<parts>-<frame>.png`, where `<parts>` is the names joined by `+`, or `reel`. `sheet` with `proofs`
        /// names writes those proofs of the whole reel. `sheet` without any of them writes for each part named,
        /// or each key of the reel, the part's proof in the film, or its `Motion.Reel.Proof.overview(of:)`, and
        /// when no part is named, every proof of the whole reel. A proof named `<name>`, a part's by its key,
        /// is written as its sheets `sheet-<name>.png` or `sheet-<name>-<sheet>.png`, its stills
        /// `<name>-<frame>.png` and its pictures `<name>-<picture>.png`. A reel is drawn with only the layers
        /// `layers` names, or none when `bare`; a layer or proof name the film does not have is refused with
        /// `.layer` or `.proof` before anything is written. `frames` writes every frame as `<frame>.png`. `movie` writes
        /// `<parts>.mp4` through `Motion.Encoding` at the reel's size and rate, replacing one already there.
        /// Frames are numbered with at least five digits.
        public static func run<Key>(_ film: Film<Key>, _ request: Request) async throws(Error) -> [Swift.String] {
            let reel = try layered(film.reel, request)
            let keys = try keys(request.parts, in: reel)
            let named = try request.proofs.map { name throws(Error) in
                guard let proof = film.proofs[name] else { throw .proof(name) }
                return (name, proof)
            }
            let label = request.parts.isEmpty ? "reel" : request.parts.joined(separator: "+")
            let directory = try path(request.output)
            do throws(File.System.Create.Directory.Error) {
                try File.Directory(directory).create.recursive()
            } catch {
                throw .directory(error)
            }
            switch request.action {
            case .sheet where !request.at.isEmpty || !request.stills.isEmpty:
                let sheets = request.at.isEmpty ? [] : [Motion.Reel<Key>.Sheet("at", frames: request.at, columns: request.columns)]
                let proof = Motion.Reel<Key>.Proof(sheets: sheets, stills: request.stills)
                return try await prints(proof, of: keys, named: label, from: reel, into: request.output)

            case .sheet where !named.isEmpty:
                var written: [Swift.String] = []
                for (name, proof) in named {
                    written += try await prints(proof, of: nil, named: name, from: reel, into: request.output)
                }
                return written

            case .sheet:
                var written: [Swift.String] = []
                for key in keys ?? Self.keys(of: reel) {
                    let proof = film.parts[key] ?? .overview(of: Cardinal(UInt(reel.positions(of: [key]).count)))
                    written += try await prints(proof, of: [key], named: Swift.String(describing: key), from: reel, into: request.output)
                }
                guard keys == nil else { return written }
                for name in film.proofs.keys.sorted() {
                    guard let proof = film.proofs[name] else { continue }
                    written += try await prints(proof, of: nil, named: name, from: reel, into: request.output)
                }
                return written

            case .frames:
                let feed = reel.sequence(keys)
                var written: [Swift.String] = []
                var position = Ordinal.zero
                while true {
                    let made: Result<[Byte], W3C_PNG::W3C_PNG.Image.Error>?
                    do throws(Motion.Hosting.Picture.Frames.Error) {
                        made = try await feed.frame(at: position)
                    } catch {
                        throw .frames(error)
                    }
                    guard let made else { return written }
                    let bytes: [Byte]
                    do throws(W3C_PNG::W3C_PNG.Image.Error) {
                        bytes = try made.get()
                    } catch {
                        throw .png(error)
                    }
                    let file = request.output + "/" + numbered(position) + ".png"
                    try write(bytes, to: file)
                    written.append(file)
                    position += Cardinal.one
                }

            #if canImport(AVFoundation)
            case .movie:
                let file = request.output + "/" + label + ".mp4"
                let movie = try path(file)
                do throws(File.System.Delete.Error) {
                    try File(movie).delete.ifExists()
                } catch {
                    throw .delete(error)
                }
                let (count, feed) = reel.movie(keys)
                let encoding = Motion.Encoding(width: reel.width, height: reel.height, rate: reel.rate)
                do throws(Motion.Encoding.Error) {
                    try await encoding.write(frames: count, to: URL(filePath: file)) { position in
                        do throws(Motion.Hosting.Picture.Frames.Error) {
                            return try await feed.frame(at: position)
                        } catch {
                            return nil
                        }
                    }
                } catch {
                    throw .movie(error)
                }
                return [file]

            case .compare:
                let reference = try await decoding(request.reference)
                let pairs = try layout(width: request.width, font: request.font, of: reference)
                let positions = keys.map { reel.positions(of: $0).count } ?? Int(clamping: reel.frames)
                let length = reel.rate.start(of: Integer(positions))
                return try await compare(reference, length: length, step: request.step, count: request.pairs, as: pairs, into: request.output) {
                    instants throws(Error) in
                    do throws(Motion.Hosting.Picture.Frames.Error) {
                        return try await reel.frames(at: instants, of: keys)
                    } catch {
                        throw .frames(error)
                    }
                }
            #endif
            }
        }

        /// The reel with only the layers the request names, by `String(describing:)` of their keys, or none when
        /// it asks for a bare reel, or as it is. A name no layer has fails with `.layer`.
        static func layered<Key>(_ reel: Motion.Reel<Key>, _ request: Request) throws(Error) -> Motion.Reel<Key> {
            guard !request.bare else { return reel.layered([]) }
            guard !request.layers.isEmpty else { return reel }
            let keys = try request.layers.map { name throws(Error) in
                guard let layer = reel.layers.first(where: { Swift.String(describing: $0.key) == name }) else { throw .layer(name) }
                return layer.key
            }
            return reel.layered(keys)
        }
    }

    #if canImport(AVFoundation)
    extension Motion.Command {
        /// Reads the command line over movie files, does what it asks, says how many files it wrote, and ends the
        /// process: with 0 when it wrote them, 0 after printing the help it was asked for, the arguments' own code
        /// when they could not be read, and 1 when writing failed.
        public static func main(arguments: [Swift.String]? = nil) async -> Never {
            let request: Movies
            do throws(Command_Primitive::Command.Error) {
                request = try Movies.parse(arguments ?? Array(CommandLine.arguments.dropFirst()))
            } catch {
                if case .helpRequested = error {
                    print(Movies.help, terminator: "")
                } else {
                    print(Command_Primitive::Command.Diagnostic.message(for: error))
                }
                Process.Exit.normal(Command_Primitive::Command.Diagnostic.exitCode(for: error))
            }
            let clock = ContinuousClock()
            let began = clock.now
            do throws(Error) {
                let written = try await run(request)
                print("\(written.count) files written in \(clock.now - began)")
                Process.Exit.normal(0)
            } catch {
                print("error: \(error)")
                Process.Exit.normal(1)
            }
        }

        /// Does what a request over movie files asks and gives the paths written, in the order written.
        ///
        /// `compare` reads the reference and the movie through `Motion.Decoding`, sets them side by side by
        /// `Motion.Pairs` at every step from zero until the longer one ends, the reference on the left, `pairs`
        /// pairs to a sheet, two to a row, and writes the sheets into the directory, made if missing, as
        /// `pairs-<sheet>.png` numbered from zero; each frame is `width` wide and as tall as keeps the
        /// reference's shape, and the instants are written in the font given, or not at all. `score` lays the
        /// sound under the movie as one `Motion.Encoding.Cue` and `reduce` makes the movie smaller with
        /// `Motion.Encoding.reduced(_:to:as:)`; each replaces a file already at its output.
        public static func run(_ request: Movies) async throws(Error) -> [Swift.String] {
            let files = request.files
            switch request.action {
            case .compare:
                let reference = try await decoding(files[0])
                let other = try await decoding(files[1])
                let pairs = try layout(width: request.width, font: request.font, of: reference)
                let length = Swift.max(reference.inspection.duration, other.inspection.duration)
                return try await compare(reference, length: length, step: request.step, count: request.pairs, as: pairs, into: files[2]) {
                    instants throws(Error) in
                    do throws(Motion.Encoding.Error) {
                        return try await other.frames(at: instants)
                    } catch {
                        throw .movie(error)
                    }
                }

            case .score:
                try replace(files[2])
                let cue = Motion.Encoding.Cue(
                    URL(filePath: files[1]),
                    offset: request.offset,
                    at: request.at,
                    gain: request.gain,
                    fadeIn: request.fadeIn,
                    fadeOut: request.fadeOut
                )
                do throws(Motion.Encoding.Error) {
                    try await Motion.Encoding.score(URL(filePath: files[0]), with: [cue], to: URL(filePath: files[2]))
                } catch {
                    throw .movie(error)
                }
                return [files[2]]

            case .reduce:
                try replace(files[1])
                do throws(Motion.Encoding.Error) {
                    try await Motion.Encoding.reduced(URL(filePath: files[0]), to: URL(filePath: files[1]), as: request.preset)
                } catch {
                    throw .movie(error)
                }
                return [files[1]]
            }
        }

        /// A movie opened for reading frames, or `.movie`.
        static func decoding(_ file: Swift.String) async throws(Error) -> Motion.Decoding {
            do throws(Motion.Encoding.Error) {
                return try await Motion.Decoding(URL(filePath: file))
            } catch {
                throw .movie(error)
            }
        }

        /// Pairs `width` wide and as tall as keeps the reference's shape, labelled in the font at `font`, or not
        /// labelled when it is empty.
        static func layout(width: Cardinal, font: Swift.String, of reference: Motion.Decoding) throws(Error) -> Motion.Pairs {
            let wide = Swift.max(Int(clamping: reference.inspection.width), 1)
            let tall = Int(clamping: width) * Int(clamping: reference.inspection.height) / wide
            guard !font.isEmpty else { return Motion.Pairs(width: width, height: Cardinal(UInt(tall))) }
            let file = try path(font)
            let bytes: [Byte]
            do throws(File.System.Read.Full.Error) {
                bytes = try File(file).read.bytes()
            } catch {
                throw .font(error)
            }
            return Motion.Pairs(width: width, height: Cardinal(UInt(tall)), label: Motion.Pairs.Label(font: bytes))
        }

        /// Sheets of the reference beside another film at every step from zero before `length`, `count` pairs to
        /// a sheet, written into a directory, made if missing, as `pairs-<sheet>.png`.
        static func compare(
            _ reference: Motion.Decoding,
            length: Rational,
            step: Rational,
            count: Cardinal,
            as pairs: Motion.Pairs,
            into directory: Swift.String,
            other: ([Rational]) async throws(Error) -> [Raster<Motion.Pixel>?]
        ) async throws(Error) -> [Swift.String] {
            let folder = try path(directory)
            do throws(File.System.Create.Directory.Error) {
                try File.Directory(folder).create.recursive()
            } catch {
                throw .directory(error)
            }
            var written: [Swift.String] = []
            for (sheet, instants) in Motion.Pairs.instants(every: step, before: length, count: count).enumerated() {
                let left: [Raster<Motion.Pixel>?]
                do throws(Motion.Encoding.Error) {
                    left = try await reference.frames(at: instants)
                } catch {
                    throw .movie(error)
                }
                let right = try await other(instants)
                let set = zip(instants, zip(left, right)).map { Motion.Pairs.Pair(time: $0, reference: $1.0, other: $1.1) }
                let bytes: [Byte]
                do throws(Motion.Pairs.Error) {
                    bytes = try pairs.png(set)
                } catch {
                    throw .pairs(error)
                }
                let file = directory + "/pairs-" + numbered(Ordinal(UInt(sheet))) + ".png"
                try write(bytes, to: file)
                written.append(file)
            }
            return written
        }

        /// Removes a file about to be written again, if it is there.
        static func replace(_ file: Swift.String) throws(Error) {
            let written = try path(file)
            do throws(File.System.Delete.Error) {
                try File(written).delete.ifExists()
            } catch {
                throw .delete(error)
            }
        }

    }
    #endif

    extension Motion.Command {
        /// The keys of the parts with these names, by `String(describing:)`, in the order named; nil for no
        /// names. A name no part has fails with `.part`.
        static func keys<Key>(_ names: [Swift.String], in reel: Motion.Reel<Key>) throws(Error) -> [Key]? {
            guard !names.isEmpty else { return nil }
            let known = keys(of: reel)
            return try names.map { name throws(Error) in
                guard let key = known.first(where: { Swift.String(describing: $0) == name }) else { throw .part(name) }
                return key
            }
        }

        /// Each key of the reel's parts once, in the order of the parts.
        static func keys<Key>(of reel: Motion.Reel<Key>) -> [Key] {
            var seen: Set<Key> = []
            return reel.parts.map(\.key).filter { seen.insert($0).inserted }
        }

        /// A proof printed and written: each sheet as `sheet-<name>.png`, or `sheet-<name>-<sheet>.png` for a
        /// named sheet, each still as `<name>-<frame>.png`, and each picture as `<name>-<picture>.png`.
        static func prints<Key>(
            _ proof: Motion.Reel<Key>.Proof,
            of keys: [Key]?,
            named name: Swift.String,
            from reel: Motion.Reel<Key>,
            into directory: Swift.String
        ) async throws(Error) -> [Swift.String] {
            let prints: Motion.Reel<Key>.Prints
            do throws(Motion.Reel<Key>.Error) {
                prints = try await reel.prints(proof, of: keys)
            } catch {
                throw Error(error)
            }
            var written: [Swift.String] = []
            for sheet in proof.sheets {
                guard let bytes = prints.sheets[sheet.name] else { continue }
                let file = directory + "/sheet-" + name + (sheet.name.isEmpty ? "" : "-" + sheet.name) + ".png"
                try write(bytes, to: file)
                written.append(file)
            }
            for still in proof.stills {
                guard let bytes = prints.stills[still] else { continue }
                let file = directory + "/" + name + "-" + numbered(still) + ".png"
                try write(bytes, to: file)
                written.append(file)
            }
            for picture in proof.pictures.keys.sorted() {
                guard let bytes = prints.pictures[picture] else { continue }
                let file = directory + "/" + name + "-" + picture + ".png"
                try write(bytes, to: file)
                written.append(file)
            }
            return written
        }

        /// A frame's number with at least five digits, zeros before it.
        static func numbered(_ frame: Ordinal) -> Swift.String {
            let digits = Swift.String(Int(bitPattern: frame))
            return Swift.String(repeating: "0", count: Swift.max(5 - digits.count, 0)) + digits
        }

        /// A path from its text, or `.path`.
        static func path(_ text: Swift.String) throws(Error) -> File.Path {
            do throws(Path.Error) {
                return try File.Path(validating: text)
            } catch {
                throw .path(text)
            }
        }

        /// Bytes written into a file at once, so that a reader sees the old file or the whole new one.
        static func write(_ bytes: [Byte], to file: Swift.String) throws(Error) {
            let path = try path(file)
            do throws(File.System.Write.Atomic.Error) {
                try File(path).write.atomic(bytes.span)
            } catch {
                throw .write(error)
            }
        }
    }
#endif
