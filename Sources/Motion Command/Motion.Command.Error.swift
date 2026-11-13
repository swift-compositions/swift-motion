#if Command
    public import Command
    public import File_System
    public import Motion
    public import Motion_Encoding
    public import Motion_Picture
    public import Picture_PNG_Integration

    extension Motion.Command {
        /// Why a command wrote nothing more.
        public enum Error: Swift.Error, Sendable {
            /// The arguments could not be read.
            case arguments(Command_Primitive::Command.Error)

            /// The reel has no part of that name.
            case part(Swift.String)

            /// A sheet or still asked for a frame beyond the frames written.
            case outside(Ordinal)

            /// The frames were not drawn.
            case frames(Motion.Hosting.Picture.Frames.Error)

            /// A sheet's tiles could not be laid out.
            case sheet(Raster<Picture::Picture.Pixel>.Error)

            /// A picture could not be made a PNG image.
            case png(W3C_PNG::W3C_PNG.Image.Error)

            /// A path written to is not a path.
            case path(Swift.String)

            /// The directory written into could not be made.
            case directory(File.System.Create.Directory.Error)

            /// A file could not be written.
            case write(File.System.Write.Atomic.Error)

            /// A movie already there could not be removed.
            case delete(File.System.Delete.Error)

            /// A movie could not be written or read.
            case movie(Motion.Encoding.Error)

            /// A sheet of pairs could not be made.
            case pairs(Motion.Pairs.Error)

            /// The font file could not be read.
            case font(File.System.Read.Full.Error)
        }
    }

    extension Motion.Command.Error {
        /// A reel's failure as a command's.
        public init<Key>(_ error: Motion.Reel<Key>.Error) {
            switch error {
            case .outside(let frame): self = .outside(frame)

            case .frames(let failure): self = .frames(failure)

            case .sheet(let failure): self = .sheet(failure)

            case .png(let failure): self = .png(failure)
            }
        }
    }
#endif
