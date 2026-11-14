#if File
    public import File_System
    public import Motion

    extension Motion.Take.Recorder {
        /// Why a recorder did not write a frame or the file.
        public enum Error: Swift.Error, Sendable {
            /// The take's own refusal: a rate the written form cannot hold, a frame of another size, or a frame whose
            /// pixels could not be read.
            case take(Motion.Take.Error)

            /// The file could not be made, written or put in place.
            case file(File.System.Write.Streaming.Error)

            /// The recorder has already finished.
            case finished
        }
    }
#endif
