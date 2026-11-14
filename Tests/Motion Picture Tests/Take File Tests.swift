#if Picture && File
    import File_System
    import Motion
    import Motion_Picture
    import Motion_Take_File
    import Picture
    import Testing

    extension `Take Tests` {
        static let damagedFrame = Motion.Hosting.Picture.Frames.Error.renderer(
            .drawing(.init(Motion.Take.Error.damaged(0))),
            at: 2
        )

        @Test func `a damaged frame of a take file drawn in a reel fails with the frame's position and the take's own reason`() async throws {
            // A still of two frames, then a take read from a file whose first frame is damaged on disk.
            let take = try Self.take([0, 1, 2], rate: .ntsc)
            let directory = try File.Path.Temporary.deterministic(
                prefix: "motion-take-reel-",
                key: Swift.String(UInt64.random(in: 0...UInt64.max)),
                suffix: ""
            )
            try File.Directory(directory).create.recursive()
            let path = directory / "take"
            try take.write(to: path)
            var bytes = try File(path).read.bytes()
            let head = 44
            var writer = try Motion.Take.Writer(rate: take.rate)
            let first = try writer.append(take.frames[0]).count - head
            bytes[head + first / 2] = Byte(bitPattern: ~bytes[head + first / 2].bitPattern)
            try File(path).write.atomic(contentsOf: bytes)
            let read = try Motion.Take(reading: path)
            let reel = Motion.Reel<Swift.String>(
                width: take.width,
                height: take.height,
                rate: .ntsc,
                parts: [
                    .init("still", frames: 2) { _ in [] },
                    .init("take", frames: 3) { frame in Picture(read, at: frame.time) },
                ]
            )
            do throws(Motion.Hosting.Picture.Frames.Error) {
                _ = try await reel.hosting(workers: 1).rasters([0, 1, 2, 3, 4])
                Issue.record("A damaged frame draws")
            } catch {
                #expect(error == Self.damagedFrame)
                #expect(reel.failure(error) == .frames(Self.damagedFrame))
                guard case .renderer(.drawing(let failure), at: _) = error else { return }
                #expect(failure.error(as: Motion.Take.Error.self) == .damaged(0))
            }
            await #expect(throws: Motion.Reel<Swift.String>.Error.frames(Self.damagedFrame)) {
                try await reel.prints(Motion.Reel<Swift.String>.Proof(stills: [2]))
            }
        }
    }
#endif
