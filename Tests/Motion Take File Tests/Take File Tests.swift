#if File
    import File_System
    import Motion
    import Motion_Take_File
    import Testing

    @Suite struct `Recorder Tests` {
        static func raster(seed: Int, width: Int = 16, height: Int = 9) throws -> Raster<Motion.Pixel> {
            let bytes = (0..<(width * height)).flatMap { index -> [UInt8] in
                let alpha = UInt8(truncatingIfNeeded: 96 + (index * 3 + seed) % 160)
                let level = UInt8(truncatingIfNeeded: index * 11 + seed * 29)
                return [UInt8(Int(level) % (Int(alpha) + 1)), alpha / 3, alpha / 2, alpha]
            }
            return try Raster(width: Cardinal(UInt(width)), height: Cardinal(UInt(height)), bytes: bytes)
        }

        static func take() throws -> Motion.Take {
            try Motion.Take([3, 4, 3, 5].map { try raster(seed: $0) }, rate: .ntsc)
        }

        /// A new, empty directory of its own under the system's temporary directory.
        static func directory() throws -> File.Path {
            let path = try File.Path.Temporary.deterministic(prefix: "motion-take-", key: Swift.String(UInt64.random(in: 0...UInt64.max)), suffix: "")
            try File.Directory(path).create.recursive()
            return path
        }

        static func names(in directory: File.Path) throws -> [Swift.String] {
            try File.Directory.Contents.names(at: File.Directory(directory)).compactMap { name in Swift.String(name) }.sorted()
        }

        @Test func `a take recorded into a file and read from it is the take, frame for frame`() throws {
            let take = try Self.take()
            let path = try Self.directory() / "take"
            let recorder = try Motion.Take.Recorder(to: path, rate: take.rate)
            for frame in take.frames { try recorder.append(try frame.raster()) }
            #expect(recorder.count == 4)
            let recorded = try recorder.finish()
            let read = try Motion.Take(reading: path)
            for kept in [recorded, read] {
                #expect(kept == take && kept.rate == .ntsc && kept.width == 16 && kept.height == 9)
                #expect(try kept.frames.map { try $0.raster() } == take.frames.map { try $0.raster() })
                #expect(kept.frames.allSatisfy { $0.held == nil })
            }
            #expect(try File(path).read.bytes() == take.written())
            #expect(throws: Motion.Take.Recorder.Error.self) { try recorder.append(take.frames[0]) }
        }

        @Test func `a take written to a path replaces the file there and reads back equal`() throws {
            let take = try Self.take()
            let directory = try Self.directory()
            let path = directory / "take"
            try File(path).write.atomic(contentsOf: [Byte(bitPattern: 1)])
            let written = try take.write(to: path)
            #expect(written == take)
            #expect(try Motion.Take(reading: path) == take)
            #expect(try Self.names(in: directory) == ["take"])
        }

        @Test func `a recorder let go of before it finishes leaves nothing behind`() throws {
            let directory = try Self.directory()
            do {
                let recorder = try Motion.Take.Recorder(to: directory / "take", rate: .thirty)
                try recorder.append(try Self.raster(seed: 1))
            }
            #expect(try Self.names(in: directory).isEmpty)
        }

        @Test func `a damaged frame on disk fails with its position when read, a cut file as truncated, a missing one as unreadable`() throws {
            let take = try Self.take()
            let directory = try Self.directory()
            let path = directory / "take"
            try take.write(to: path)
            var bytes = try File(path).read.bytes()
            let head = 44
            var writer = try Motion.Take.Writer(rate: take.rate)
            let first = try writer.append(take.frames[0]).count - head
            bytes[head + first / 2] = Byte(bitPattern: ~bytes[head + first / 2].bitPattern)
            try File(path).write.atomic(contentsOf: bytes)
            let read = try Motion.Take(reading: path)
            #expect(throws: Motion.Take.Error.damaged(2)) { try read.frames[2].raster() }
            #expect(try read.frames[1].raster() == take.frames[1].raster())

            try File(path).write.atomic(contentsOf: bytes.prefix(head + first / 2))
            #expect(throws: Motion.Take.Error.truncated) { try Motion.Take(reading: path) }
            #expect(throws: Motion.Take.Error.truncated) { try read.frames[0].raster() }

            let missing = directory / "missing"
            #expect {
                try Motion.Take(reading: missing)
            } throws: { error in
                if case .unreadable = error as? Motion.Take.Error { true } else { false }
            }
        }
    }
#endif
