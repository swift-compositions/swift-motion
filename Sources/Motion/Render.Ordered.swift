extension Render {
    /// Ordered fan-in: frames finished out of order are handed on in order, each as soon as
    /// every frame before it has arrived.
    public struct Ordered<Value: Sendable>: Sendable {
        var next = 0
        var waiting: [Int: Value] = [:]

        public init() {}

        public mutating func arrive(_ index: Int, _ value: Value) -> [Value] {
            waiting[index] = value
            var ready: [Value] = []
            while let value = waiting.removeValue(forKey: next) {
                ready.append(value)
                next += 1
            }
            return ready
        }
    }
}
