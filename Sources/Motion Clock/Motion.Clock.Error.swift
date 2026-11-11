extension Motion.Clock {
    public enum Error: Swift.Error, Hashable, Sendable {
        /// The shim library is not in the process.
        case absent
        /// The shim library is in the process but was not there at launch, so calls are not routed through it.
        case unhooked
        /// The instant lies before where the clock stands; it never runs backwards.
        case backwards
        /// The instant is more nanoseconds from the freeze than the clock can count.
        case beyond
    }
}
