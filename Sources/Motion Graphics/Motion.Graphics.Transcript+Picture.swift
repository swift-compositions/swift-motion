#if Graphics
    public import Motion
    public import Picture

    extension Picture {
        /// A transcript at a moment: each line that has a moment, its first baseline the origin's lowered by the
        /// leading once for every row of the lines before it.
        public init(_ transcript: Motion.Graphics.Transcript, at moment: Motion.Graphics.Transcript.Moment) throws(Picture.Text.Error) {
            let advance = try transcript.style.advance
            var elements: [Picture.Element] = []
            for ((line, baseline), state) in zip(zip(transcript.lines, transcript.baselines), moment.lines) {
                let origin = Picture.Plane.Point<2>([transcript.origin[0], baseline])
                elements.append(contentsOf: try Picture(line, at: state, from: origin, advance: advance, style: transcript.style).elements)
            }
            self.init(elements)
        }
    }
#endif
