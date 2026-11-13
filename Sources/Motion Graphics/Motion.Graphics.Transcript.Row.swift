#if Graphics
    import Motion

    extension Motion.Graphics.Transcript {
        /// One row of a line: its characters and how many of the line's characters come before it.
        struct Row: Sendable, Hashable {
            var start: Int
            var text: Substring
        }
    }

    extension Motion.Graphics.Transcript.Row {
        /// How many of the row's characters stand when a number of the line's characters do.
        func standing(_ count: Int) -> Int {
            Swift.min(Swift.max(count - start, 0), text.count)
        }
    }
#endif
