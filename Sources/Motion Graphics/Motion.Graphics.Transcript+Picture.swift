#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A transcript at a moment: each line that has a moment, its first baseline the place's lowered by the
        /// leading once for every row of the lines before it, from the lines set when the transcript was made.
        public init(_ transcript: Motion.Graphics.Transcript, at moment: Motion.Graphics.Transcript.Moment) {
            var elements: [Picture.Element] = []
            for (((line, setting), baseline), state) in zip(zip(zip(transcript.lines, transcript.settings), transcript.baselines), moment.lines) {
                let origin = Picture.Plane.Point<2>([transcript.place[0], baseline])
                elements.append(contentsOf: Picture(setting, of: line.mark, at: state, from: origin, advance: transcript.advance, style: transcript.style).elements)
            }
            self.init(elements)
        }
    }
#endif
