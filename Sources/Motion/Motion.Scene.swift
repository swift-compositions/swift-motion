public import Raster
public import Rate

extension Motion {
    /// A scene, state first: a pure function from time, in seconds, to the state its picture draws.
    public struct Scene<State: Hashable & Sendable>: Sendable {
        public let rate: Rate
        public let frames: Cardinal
        public let state: @Sendable (Rational) -> State

        public init(rate: Rate, frames: Cardinal, state: @escaping @Sendable (Rational) -> State) {
            self.rate = rate
            self.frames = frames
            self.state = state
        }
    }
}

extension Motion.Scene {
    /// The distinct states in first-shown order, and which of them each frame shows. No plan holds more
    /// frames than an array can.
    public var plan: Plan {
        var index: [State: Ordinal] = [:]
        var states: [State] = []
        let shows = (0..<Int(clamping: frames)).map { frame in
            let state = state(rate.centre(of: Integer(frame)))
            if let known = index[state] { return known }
            let position = Ordinal(UInt(states.count))
            index[state] = position
            states.append(state)
            return position
        }
        return Plan(states: states, shows: shows)
    }
}
