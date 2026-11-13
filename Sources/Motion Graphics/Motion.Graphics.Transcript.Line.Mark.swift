#if Graphics
    public import Motion
    public import Picture

    extension Motion.Graphics.Transcript.Line {
        /// What stands before a line's words, followed by one empty cell.
        public enum Mark: Sendable, Hashable {
            /// A prompt: the mark a shell writes before what is typed, in the style's mark ink. The words are
            /// set in the typed ink.
            case prompt(Swift.String)

            /// A diagnostic's label, such as `error:`, in the mark's font and its own colour. The words are set
            /// in the said ink.
            case label(Swift.String, Picture.Color)

            /// Nothing: the words start at the origin, in the said ink.
            case plain
        }
    }
#endif
