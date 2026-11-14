#if File
    public import AVFoundation
    import File_System
    public import Motion

    extension Motion.Encoding {
        /// The best movie that is at most `limit` bytes on file, or `.limit` when none can be.
        ///
        /// A movie whose file is already within the limit is copied as it is. Otherwise its picture is encoded
        /// again, its frames, their durations and its sound kept, at sizes of its shape from its own down: each
        /// side three quarters of the size before, rounded down to an even number of pixels, while the shorter
        /// side is at least `side`, and last the size whose shorter side is `side`. At each size the bit rate is
        /// what the limit leaves the picture over the movie's length, less the sound's bytes and an allowance for
        /// the file's index, and at most four bits per pixel per second; a size at which that is less than half
        /// a bit per pixel per second is passed over for the next. A movie written larger than the limit is
        /// written again at that size, up to three times in all, its bit rate cut by how far the picture went
        /// over and a tenth more. The first that is within the limit is kept: the largest size and, at it, the
        /// most bits the limit allows. Each size is measured on the written file, never predicted. When even the
        /// smallest size at half a bit per pixel per second is over the limit, it fails with `.limit` and the
        /// fewest bytes a movie was written in. A file already at `url` fails with `.writer` before anything is
        /// written.
        public static func reduced(_ movie: URL, to url: URL, within limit: Cardinal) async throws(Motion.Encoding.Error) {
            guard !exists(url) else { throw .writer("a file is already at \(url.lastPathComponent)") }
            let source = try await Inspection(of: movie)
            let length = try bytes(of: movie)
            guard length > limit else {
                try copy(movie, to: url)
                return
            }
            let sound = try await soundBytes(of: movie)
            let room = Int(clamping: limit) - Int(clamping: sound) - Self.allowance(frames: source.frames)
            let seconds = Swift.max(source.duration.approximation, 1e-9)
            let sizes = ladder(width: source.width, height: source.height)
            var fewest: Cardinal?
            for (rung, size) in sizes.enumerated() {
                let last = rung == sizes.indices.last
                let most = Int(clamping: bits(width: size.width, height: size.height))
                let least = Swift.max(most / 8, 1)
                var rate = Swift.min(most, Int(Double(Swift.max(room, 0)) * 8 / seconds))
                if rate < least {
                    guard last else { continue }
                    rate = least
                }
                for again in 0..<3 {
                    let attempt = url.deletingLastPathComponent().appending(path: ".\(url.lastPathComponent).\(getpid()).\(rung).\(again).mp4")
                    defer { remove(attempt) }
                    try await reduced(movie, to: attempt, width: size.width, height: size.height, bits: Cardinal(UInt(rate)))
                    let written = try bytes(of: attempt)
                    fewest = Swift.min(fewest ?? written, written)
                    if written <= limit {
                        try move(attempt, to: url)
                        return
                    }
                    let picture = Swift.max(Double(Int(clamping: written) - Int(clamping: sound)), 1)
                    let allowed = Double(Int(clamping: limit) - Int(clamping: sound))
                    rate = Int(Double(rate) * allowed / picture * 0.9)
                    guard rate >= least else { break }
                }
            }
            throw .limit(limit, fewest: fewest ?? length)
        }

        /// The file system's path of a file URL, or `.writer`.
        static func path(of url: URL) throws(Motion.Encoding.Error) -> File.Path {
            do throws(File.Path.Error) {
                return try File.Path(validating: url.path)
            } catch {
                throw .writer("\(url.lastPathComponent) is no path: \(error)")
            }
        }

        /// How many bytes a file holds, or `.reader`.
        static func bytes(of url: URL) throws(Motion.Encoding.Error) -> Cardinal {
            let at = try path(of: url)
            let info: File.System.Metadata.Info
            do throws(Kernel.File.Stats.Error) {
                info = try File.System.Stat.info(at: at)
            } catch {
                throw .reader("\(url.lastPathComponent) cannot be measured: \(error)")
            }
            guard let size = UInt(exactly: info.size.underlying) else { throw .reader("\(url.lastPathComponent) cannot be measured") }
            return Cardinal(size)
        }

        /// Whether anything is at `url`.
        static func exists(_ url: URL) -> Bool {
            do throws(Motion.Encoding.Error) {
                return File.System.Stat.exists(at: try path(of: url))
            } catch {
                return false
            }
        }

        /// Copies a file to `url`, where no file may be, or `.writer`.
        static func copy(_ source: URL, to url: URL) throws(Motion.Encoding.Error) {
            let (from, to) = (try path(of: source), try path(of: url))
            do throws(File.System.Copy.Error) {
                try File.System.Copy.copy(from: from, to: to)
            } catch {
                throw .writer("\(source.lastPathComponent) could not be copied to \(url.lastPathComponent): \(error)")
            }
        }

        /// Moves a file to `url`, where no file may be, or `.writer`.
        static func move(_ source: URL, to url: URL) throws(Motion.Encoding.Error) {
            let (from, to) = (try path(of: source), try path(of: url))
            do throws(File.System.Move.Error) {
                try File.System.Move.move(from: from, to: to)
            } catch {
                throw .writer("\(source.lastPathComponent) could not become \(url.lastPathComponent): \(error)")
            }
        }

        /// Removes the file at `url`, where there is one; a file that is not there is no failure.
        static func remove(_ url: URL) {
            do throws(Motion.Encoding.Error) {
                let at = try path(of: url)
                guard File.System.Stat.exists(at: at) else { return }
                do throws(File.System.Delete.Error) {
                    try File.System.Delete.delete(at: at)
                } catch {}
            } catch {}
        }
    }
#endif
