#if Picture
    public import Motion
    public import Picture
    import Synchronization

    extension Motion.Reel.Part {
        /// What draws a part's frames, built once, by the first frame drawn, on whichever thread draws it; a
        /// thread that asks while it is being built waits for it. A building that fails is not tried again: every
        /// frame of the part fails as it did.
        final class Drawing: Sendable {
            let state: Mutex<State>

            enum State: Sendable {
                case waiting(@Sendable () throws(Typesetting.Error) -> @Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture)
                case built(@Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture)
                case failed(Typesetting.Error)
            }

            init(_ building: @escaping @Sendable () throws(Typesetting.Error) -> @Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture) {
                self.state = Mutex(.waiting(building))
            }

            /// The drawing, built now if it was not before, or why it could not be built.
            func drawn() throws(Typesetting.Error) -> @Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture {
                let result: Result<@Sendable (Motion.Reel<Key>.Frame) -> Picture::Picture, Typesetting.Error> = state.withLock { state in
                    switch state {
                    case .built(let picture):
                        return .success(picture)

                    case .failed(let error):
                        return .failure(error)

                    case .waiting(let building):
                        do throws(Typesetting.Error) {
                            let picture = try building()
                            state = .built(picture)
                            return .success(picture)
                        } catch {
                            state = .failed(error)
                            return .failure(error)
                        }
                    }
                }
                return try result.get()
            }
        }
    }
#endif
