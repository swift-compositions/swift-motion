import Cardinal
public import Rational

extension Frame {
    /// Frames per second as an exact rational, so 30000/1001 is 30000/1001 and not 29.97.
    public struct Rate: Sendable, Hashable {
        public let perSecond: Rational
        /// Frames in `denominator` seconds, in lowest terms: 30000 for 30000/1001.
        public let numerator: Int
        /// Seconds that hold `numerator` frames, in lowest terms: 1001 for 30000/1001.
        public let denominator: Int

        public init(_ numerator: Int, per denominator: Int = 1) {
            precondition(numerator > 0 && denominator > 0, "a frame rate is positive")
            var (a, b) = (numerator, denominator)
            while b != 0 { (a, b) = (b, a % b) }
            self.perSecond = Rational.exact(numerator, denominator)
            self.numerator = numerator / a
            self.denominator = denominator / a
        }
    }
}

extension Frame.Rate {
    public static let film = Self(24000, per: 1001)
    public static let ntsc = Self(30000, per: 1001)
    public static let thirty = Self(30)

    /// When frame `index` starts, in seconds.
    public func start(of index: Int) -> Rational { Rational(index).over(perSecond) }

    /// The middle of frame `index`, in seconds: the time its picture shows.
    public func centre(of index: Int) -> Rational { Rational(2 * index + 1).over(Rational(2) * perSecond) }

    /// The frame showing at `seconds`.
    public func index(at seconds: Rational) -> Int { (seconds * perSecond).floor }

    /// How many audio samples at `rate` per second fall in frame `index`. Over any run of frames
    /// the counts add up to the exact floor of its duration, so picture and sound never drift.
    public func samples(in index: Int, at rate: Int) -> Int {
        (start(of: index + 1) * Rational(rate)).floor - (start(of: index) * Rational(rate)).floor
    }

    /// The SMPTE ST 12 address of frame `index`: drop-frame at 30000/1001 and 60000/1001,
    /// non-drop at whole rates, and nil where ST 12 has no nominal rate.
    public func timecode(of index: Int) -> SMPTE_ST_12.Timecode? {
        let nominal = (perSecond + Rational.exact(1, 2)).floor
        let rate: SMPTE_ST_12.Timecode.Rate? = SMPTE_ST_12.Timecode.Rate.allCases.first { $0.nominal == nominal }
        guard let rate, index >= 0 else { return nil }
        let drop = perSecond.denominator != .one && nominal % 30 == 0
        do throws(SMPTE_ST_12.Timecode.Error) {
            return try SMPTE_ST_12.Timecode(frame: Cardinal(UInt(index)), rate: rate, counting: drop ? .drop : .nonDrop)
        } catch {
            return nil
        }
    }
}
