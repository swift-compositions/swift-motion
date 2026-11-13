public import AVFoundation
public import Motion

extension Motion.Encoding {
    /// A stretch of a sound file laid under a movie's picture: where in the sound it starts, when in the film it
    /// enters, how loud it plays, and how long it takes to fade in and out.
    ///
    /// Times are exact fractions of seconds. The stretch plays from `offset` in the sound, entering at `entry` in
    /// the film, until the sound or the picture ends, whichever is first. Its level is `gain` times the sound's
    /// own; it rises from silence over the first `rise` of the stretch and falls to silence over its last
    /// `fall`, each in a straight line, and two fades longer together than the stretch are each cut to half.
    public struct Cue: Sendable, Hashable {
        /// The sound file.
        public var sound: URL

        /// Where in the sound the stretch starts, in seconds.
        public var offset: Rational

        /// The film time at which the stretch enters, in seconds.
        public var entry: Rational

        /// The level the stretch plays at, as a multiple of the sound's own: 1 leaves it as it is.
        public var gain: Float

        /// How long the stretch takes to rise from silence, in seconds.
        public var rise: Rational

        /// How long the stretch takes to fall to silence at its end, in seconds.
        public var fall: Rational

        public init(
            _ sound: URL,
            offset: Rational = .zero,
            at entry: Rational = .zero,
            gain: Float = 1,
            rise: Rational = .zero,
            fall: Rational = .zero
        ) {
            self.sound = sound
            self.offset = offset
            self.entry = entry
            self.gain = gain
            self.rise = rise
            self.fall = fall
        }
    }
}
