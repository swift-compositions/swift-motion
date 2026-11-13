#if Picture
    public import Motion
    public import Picture
    import Synchronization

    extension Motion.Reel.Part {
        /// What draws a part's frames, built once, by the first frame drawn, on whichever thread draws it; a
        /// thread that asks while it is being built waits for it.
        final class Drawing: Sendable {
            let state: Mutex<State>

            enum State: Sendable {
                case waiting(@Sendable () -> @Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture)
                case built(@Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture)
            }

            init(_ building: @escaping @Sendable () -> @Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture) {
                self.state = Mutex(.waiting(building))
            }

            /// The drawing, built now if it was not before.
            var drawn: @Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture {
                state.withLock { state in
                    switch state {
                    case .built(let picture):
                        return picture
                    case .waiting(let building):
                        let picture = building()
                        state = .built(picture)
                        return picture
                    }
                }
            }
        }
    }
#endif
