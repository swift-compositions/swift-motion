#if Command
    internal import AVFoundation
    import Command
    import File_System
    public import Motion
    import Motion_Encoding
    public import Motion_Picture
    import Process
    import Picture_PNG_Integration

    extension Motion {
        /// A film's command line: the executable a reel is written from calls `main(_:proofs:arguments:)` and
        /// nothing else. It reads the arguments, writes the files and the movie, and holds no drawing of its own.
        ///
        ///     reel sheet <output> [--part <key>...] [--at <frames>] [--stills <frames>] [--columns <count>]
        ///     reel frames <output> [--part <key>...]
        ///     reel movie <output> [--part <key>...]
        public enum Command {}
    }

    extension Motion.Command {
        /// Reads the command line, writes what it asks for of the reel, says how many files it wrote, and ends
        /// the process: with 0 when it wrote them, 0 after printing the help it was asked for, the arguments'
        /// own code when they could not be read, and 1 when writing failed.
        public static func main<Key>(
            _ reel: Motion.Reel<Key>,
            proofs: [Key: Motion.Reel<Key>.Proof] = [:],
            arguments: [Swift.String]? = nil
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
            let clock = ContinuousClock()
            let began = clock.now
            do throws(Error) {
                let written = try await run(reel, request, proofs: proofs)
                print("\(written.count) files written into \(request.output) in \(clock.now - began)")
                Process.Exit.normal(0)
            } catch {
                print("error: \(error)")
                Process.Exit.normal(1)
            }
        }

        /// Writes what a request asks for of the reel into its output directory, made if it is not there, and
        /// gives the paths written, in the order written.
        ///
        /// The frames are those of the parts the request names, by `String(describing:)` of their keys, played
        /// one after another, or every frame of the reel. `sheet` with frames `at` or `stills` writes one sheet
        /// of the frames `at`, `columns` to a row, as `sheet-<parts>-at.png` and the stills as
        /// `<parts>-<frame>.png`, where `<parts>` is the names joined by `+`, or `reel`. `sheet` without them
        /// writes for each part named, or each key of the reel, the part's proof in `proofs`, or its
        /// `Motion.Reel.Proof.overview(of:)`: its sheets as `sheet-<key>.png` or `sheet-<key>-<name>.png` and its
        /// stills as `<key>-<frame>.png`. `frames` writes every frame as `<frame>.png`. `movie` writes
        /// `<parts>.mp4` through `Motion.Encoding` at the reel's size and rate, replacing one already there.
        /// Frames are numbered with at least five digits.
        public static func run<Key>(
            _ reel: Motion.Reel<Key>,
            _ request: Request,
            proofs: [Key: Motion.Reel<Key>.Proof] = [:]
        ) async throws(Error) -> [Swift.String] {
            let keys = try keys(request.parts, in: reel)
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

            case .sheet:
                var written: [Swift.String] = []
                for key in keys ?? Self.keys(of: reel) {
                    let proof = proofs[key] ?? .overview(of: Cardinal(UInt(reel.positions(of: [key]).count)))
                    written += try await prints(proof, of: [key], named: Swift.String(describing: key), from: reel, into: request.output)
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
            }
        }

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
        /// named sheet, and each still as `<name>-<frame>.png`.
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
