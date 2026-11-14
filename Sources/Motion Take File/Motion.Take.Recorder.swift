#if File
    public import File_System
    public import Motion

    extension Motion.Take {
        /// Writes a take into a file a frame at a time, as it is recorded, through a `Motion.Take.Writer` and
        /// `File.System.Write.Streaming`: each frame's bytes go to the file when it is appended, so the recorder
        /// holds no pixels, only 48 bytes a frame for the index.
        ///
        /// The bytes go to a hidden file beside the path, which `finish()` renames into place, replacing a file there;
        /// until then the path is untouched, and a recorder let go of without finishing removes what it wrote.
        /// Writing blocks the calling thread.
        public final class Recorder {
            /// Where the take is written.
            public let path: File.Path

            var writer: Motion.Take.Writer
            let context: File.System.Write.Streaming.Context
            var open = true

            /// A recorder of a take at a rate into a file at a path, whose directory must exist; it fails with
            /// `.take(.rate)` for a rate the written form cannot hold, and with `.file` when the file cannot be made.
            public init(to path: File.Path, rate: Rate) throws(Error) {
                do throws(Motion.Take.Error) {
                    self.writer = try Motion.Take.Writer(rate: rate)
                } catch {
                    throw .take(error)
                }
                do throws(File.System.Write.Streaming.Error) {
                    self.context = try File.System.Write.Streaming.open(path: path, options: .init())
                } catch {
                    throw .file(error)
                }
                self.path = path
            }

            deinit {
                if open {
                    File.System.Write.Streaming.cleanup(context)
                }
            }
        }
    }

    extension Motion.Take.Recorder {
        /// How many frames have been appended.
        public var count: Int { writer.count }

        /// Writes the next frame: its compressed pixels, or only its index entry for a frame equal to one before it.
        /// It fails as `Motion.Take.Writer.append(_:)` does with `.take`, writing nothing; with `.file` when the
        /// bytes cannot be written; and with `.finished` after `finish()`.
        public func append(_ frame: Motion.Take.Frame) throws(Error) {
            guard open else { throw .finished }
            let bytes: [Byte]
            do throws(Motion.Take.Error) {
                bytes = try writer.append(frame)
            } catch {
                throw .take(error)
            }
            guard !bytes.isEmpty else { return }
            do throws(File.System.Write.Streaming.Error) {
                try File.System.Write.Streaming.write(chunk: bytes.span, to: context)
            } catch {
                throw .file(error)
            }
        }

        /// Writes a raster as the next frame, digested once.
        public func append(_ raster: Raster<Motion.Pixel>) throws(Error) {
            try append(Motion.Take.Frame(raster))
        }

        /// Writes the index and the foot, puts the file in place, and gives the take as read from the file, without
        /// reading it back: its frames read their pixels from the file when asked. It fails with `.file` when the
        /// file cannot be written or put in place, leaving the path as it was, and with `.finished` the second time.
        @discardableResult
        public func finish() throws(Error) -> Motion.Take {
            guard open else { throw .finished }
            let tail = writer.tail()
            do throws(File.System.Write.Streaming.Error) {
                try File.System.Write.Streaming.write(chunk: tail.span, to: context)
                try File.System.Write.Streaming.commit(context)
            } catch {
                throw .file(error)
            }
            open = false
            return writer.take(reading: Motion.Take.reading(path))
        }
    }
#endif
