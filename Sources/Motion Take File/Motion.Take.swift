#if File
    public import File_System
    public import Motion

    extension Motion.Take {
        /// The take written in the file at a path, as `init(length:reading:)` reads it: the head, the index and the
        /// foot are read now, and each frame reads its own bytes from the file, and nothing else, every time its
        /// `raster()` is asked for, keeping nothing. A file that cannot be read fails with `.unreadable` and the
        /// file system's reason.
        ///
        /// The take holds the path and, for each frame, where its bytes are and its digest, never pixels. The
        /// frames read the file as it is when they are asked, so a file replaced or cut short since fails then.
        /// Reading blocks the calling thread.
        public init(reading path: File.Path) throws(Error) {
            let length: Int64
            do throws(Kernel.File.Stats.Error) {
                length = try File.System.Stat.info(at: path).size.underlying
            } catch {
                throw .unreadable(Swift.String(describing: error))
            }
            try self.init(length: UInt64(clamping: length), reading: Self.reading(path))
        }

        /// Writes the take to a path through a `Recorder`, which writes the whole file or none of it, and gives the
        /// take as read from the file; it fails as the recorder does.
        @discardableResult
        public func write(to path: File.Path) throws(Recorder.Error) -> Motion.Take {
            let recorder = try Recorder(to: path, rate: rate)
            for frame in frames {
                try recorder.append(frame)
            }
            return try recorder.finish()
        }

        /// Up to `count` bytes of the file at a path from an offset, by `File.System.Read.Range`.
        static func reading(_ path: File.Path) -> @Sendable (UInt64, Int) throws(Error) -> [Byte] {
            { (offset: UInt64, count: Int) throws(Error) -> [Byte] in
                guard let start = Int64(exactly: offset), let count = Int64(exactly: count) else { return [] }
                do throws(File.System.Read.Range.Error) {
                    return try File.System.Read.Range.bytes(at: path, from: Kernel.File.Offset(start), count: Kernel.File.Size(count))
                } catch {
                    throw .unreadable(Swift.String(describing: error))
                }
            }
        }
    }
#endif
