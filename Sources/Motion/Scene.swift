public import Rational

/// A scene, state first: a pure function from time to the state its picture draws.
public struct Scene<State: Hashable & Sendable>: Sendable {
    public let rate: Frame.Rate
    public let frames: Int
    public let state: @Sendable (Rational) -> State

    public init(rate: Frame.Rate, frames: Int, state: @escaping @Sendable (Rational) -> State) {
        self.rate = rate
        self.frames = frames
        self.state = state
    }
}

extension Scene {
    /// The distinct states in first-shown order, and which of them each frame shows.
    public var plan: Plan {
        var index: [State: Int] = [:]
        var states: [State] = []
        let shows = (0..<frames).map { frame in
            let state = state(rate.centre(of: frame))
            if let known = index[state] { return known }
            index[state] = states.count
            states.append(state)
            return states.count - 1
        }
        return Plan(states: states, shows: shows)
    }
}
