#if Picture
    public import Motion
    public import Picture
    public import Timeline
    public import Picture_PNG_Integration
    public import Picture_Store

    extension Motion {
        /// An edit of scenes: parts played one after another at one rate, each drawn from its own frames, with
        /// layers laid over spans of the whole.
        ///
        /// Each part lasts a number of frames and draws the picture of each of its own frames, counted from zero
        /// at its start. Each layer lives over a span of the reel's time and draws, over the part beneath, the
        /// picture of each of the reel's frames whose center falls in that span. Parts are named by a key the
        /// caller chooses; more than one part may carry the same key. Layers carry keys of the same type, by which
        /// a reel is drawn with some layers or none.
        public struct Reel<Key: Hashable & Sendable>: Sendable {
            public let width: Cardinal
            public let height: Cardinal
            public let rate: Rate
            public let background: Picture::Picture.Color
            public let parts: [Part]
            public let layers: [Layer]

            /// How much larger every length is drawn than the parts and layers give it: 1 unless the reel was
            /// `scaled(by:)`.
            public let scale: Double

            /// The parts as a sequence of `Timeline.Stack`, each layer's content the place of its part in
            /// `parts`. A part of no frames is not in it.
            let stack: Timeline.Stack<Int>

            public init(
                width: Cardinal,
                height: Cardinal,
                rate: Rate,
                over background: Picture::Picture.Color = .black,
                parts: [Part],
                layers: [Layer] = []
            ) {
                self.width = width
                self.height = height
                self.rate = rate
                self.background = background
                self.parts = parts
                self.layers = layers
                self.scale = 1
                self.stack = Self.sequence(parts, at: rate)
            }

            init(_ reel: Self, width: Cardinal, height: Cardinal, layers: [Layer], scale: Double) {
                self.width = width
                self.height = height
                self.rate = reel.rate
                self.background = reel.background
                self.parts = reel.parts
                self.layers = layers
                self.scale = scale
                self.stack = reel.stack
            }
        }
    }

    extension Motion.Reel {
        /// The same reel drawn `factor` times as large: every length of every picture, the part's and each
        /// layer's alike, is multiplied by it about the top left corner, and the width and the height are
        /// multiplied by it and rounded to the nearest pixel, halves up, never below one. At 0.5 it is a draft of
        /// half the size, about a quarter of the drawing; at 1 it is the reel itself. A factor that is not a
        /// positive finite number gives the reel as it is.
        public func scaled(by factor: Double) -> Self {
            guard factor > 0, factor.isFinite, factor != 1 else { return self }
            func side(_ length: Cardinal) -> Cardinal {
                guard length > .zero else { return .zero }
                return Cardinal(UInt(Swift.max((Double(Int(clamping: length)) * factor).rounded(.toNearestOrAwayFromZero), 1)))
            }
            return Self(self, width: side(width), height: side(height), layers: layers, scale: scale * factor)
        }

        /// A picture drawn at the reel's scale.
        func scaled(_ picture: Picture::Picture) -> Picture::Picture {
            guard scale != 1 else { return picture }
            return [.group(Picture::Picture.Group(picture, transform: .scale(scale, about: Picture::Picture.Plane.Point<2>([0.0, 0.0]))))]
        }
    }

    extension Motion.Reel {
        /// The parts that show at least one frame, one after another from instant zero with no overlap.
        static func sequence(_ parts: [Part], at rate: Rate) -> Timeline.Stack<Int> {
            let shown = parts.indices.filter { parts[$0].frames > .zero }.map { index in
                (content: index, duration: rate.start(of: Integer(Int(clamping: parts[index].frames))))
            }
            do throws(Timeline.Stack<Int>.Error) {
                return try Timeline.Stack.sequence(shown)
            } catch {
                preconditionFailure("parts of at least one frame last longer than no overlap")
            }
        }

        /// How many frames the reel lasts: the sum of its parts' frames.
        public var frames: Cardinal {
            parts.reduce(Cardinal.zero) { $0 + $1.frames }
        }

        /// The part a frame of the reel falls in and the frame of that part it is, or nil from `frames` on.
        ///
        /// The frame's center is looked up in the sequence of parts, and the part's own frame is the one its
        /// age there falls in, so the first frame of a part is zero and its last is one less than its frames.
        public func place(of position: Ordinal) -> Place? {
            let time = rate.centre(of: Integer(Int(bitPattern: position)))
            guard let moment = stack.alive(at: time).first,
                let local = rate.index(at: moment.age).exactly(UInt.self)
            else { return nil }
            return Place(part: Ordinal(UInt(moment.content)), key: parts[moment.content].key, frame: Ordinal(local))
        }

        /// The reel's frames of the parts with these keys, the parts of each key in the reel's order, the keys
        /// in the order given. Without keys, every frame of the reel.
        public func positions(of keys: [Key]? = nil) -> [Ordinal] {
            guard let keys else { return (0..<Int(clamping: frames)).map { Ordinal(UInt($0)) } }
            var starts: [Int] = []
            var start = 0
            for part in parts {
                starts.append(start)
                start += Int(clamping: part.frames)
            }
            return keys.flatMap { key in
                parts.indices.filter { parts[$0].key == key }.flatMap { index in
                    (starts[index]..<starts[index] + Int(clamping: parts[index].frames)).map { Ordinal(UInt($0)) }
                }
            }
        }

        /// The reel's instants of instants of the parts with these keys played one after another, as
        /// `positions(of:)` orders their frames: each falls in the frame at `rate.index(at:)` of it, and keeps its
        /// offset into that frame from the start of the frame in the reel. Without keys, or outside the chosen
        /// frames, an instant is its own.
        public func instants(_ instants: [Rational], of keys: [Key]?) -> [Rational] {
            guard keys != nil else { return instants }
            let positions = positions(of: keys)
            return instants.map { instant in
                let index = rate.index(at: instant)
                guard let place = index.exactly(Int.self), positions.indices.contains(place) else { return instant }
                return instant - rate.start(of: index) + rate.start(of: Integer(Int(bitPattern: positions[place])))
            }
        }

        /// The reel's frames whose center falls in a span of its time in seconds, from its start: the frames a
        /// layer of that lifetime is drawn on.
        public func positions(during span: Range<Rational>) -> [Ordinal] {
            let first = Swift.max(rate.started(before: span.lowerBound - rate.period * .half), .zero)
            let end = Swift.min(rate.started(before: span.upperBound - rate.period * .half), Integer(Int(clamping: frames)))
            guard first < end, let low = first.exactly(UInt.self), let high = end.exactly(UInt.self) else { return [] }
            return (low..<high).map { Ordinal($0) }
        }

        /// The reel's frames that the layers with this key are drawn on, in order, each once.
        public func positions(ofLayer key: Key) -> [Ordinal] {
            Swift.Array(Set(layers.filter { $0.key == key }.flatMap { positions(during: $0.timeline.lifetime) })).sorted()
        }

        /// The same reel with only the layers whose keys are given, in the reel's order; with no keys, no layers.
        public func layered(_ keys: [Key]) -> Self {
            Self(self, width: width, height: height, layers: layers.filter { keys.contains($0.key) }, scale: scale)
        }

        /// The picture of a frame of the reel: its part's picture of its own frame, with the picture of every
        /// layer alive at the frame's center laid over it in the order of the layers. From `frames` on it is
        /// empty. It fails with `.building` of the part's key when the part's drawing could not be built.
        public func picture(at position: Ordinal) throws(Error) -> Picture::Picture {
            guard let place = place(of: position) else { return .empty }
            do throws(Typesetting.Error) {
                return try picture(at: position, in: place)
            } catch {
                throw .building(place.key, error)
            }
        }

        /// The picture of a frame of the reel at its place.
        func picture(at position: Ordinal, in place: Place) throws(Typesetting.Error) -> Picture::Picture {
            let part = parts[Int(bitPattern: place.part)]
            var picture = try part.drawing.drawn()(Frame(position: place.frame, time: rate.centre(of: Integer(Int(bitPattern: place.frame)))))
            let time = rate.centre(of: Integer(Int(bitPattern: position)))
            let frame = Frame(position: position, time: time)
            for layer in layers where layer.timeline.alive(at: time) {
                picture.elements.append(contentsOf: layer.timeline.content(frame).elements)
            }
            return scaled(picture)
        }

        /// The reel's frames to draw several at a time: the frame at position `i` is the `i`th of
        /// `positions(of: keys)`, drawn as `picture(at:)` gives it at the reel's size over its background, so a
        /// part chosen alone still carries the layers it carries in the whole reel.
        public func hosting(
            _ keys: [Key]? = nil,
            workers: Cardinal? = nil,
            renderer: Picture::Picture.Renderer? = nil,
            store: Picture::Picture.Store? = nil
        ) -> Motion.Hosting.Picture.Frames {
            let chosen = keys.map { positions(of: $0) }
            let reel = self
            return Motion.Hosting.Picture.Frames(
                width: width,
                height: height,
                over: background,
                workers: workers,
                renderer: renderer,
                store: store
            ) { position throws(Typesetting.Error) in
                guard let shown = reel.position(of: position, among: chosen), let place = reel.place(of: shown) else { return .empty }
                return try reel.picture(at: shown, in: place)
            }
        }

        /// The reel's frame drawn at a position of `hosting(_:)` of the chosen positions, or nil beyond them.
        func position(of position: Ordinal, among chosen: [Ordinal]?) -> Ordinal? {
            guard let chosen else { return position }
            let place = Int(bitPattern: position)
            return place < chosen.count ? chosen[place] : nil
        }

        /// The reel's failure for a failure of its frames drawn as `hosting(keys)` draws them: a part whose
        /// drawing could not be built is named by its key, and any other failure is `.frames` of it unchanged, a
        /// renderer's error with its position and, for a drawing's own failure, its reason.
        public func failure(_ error: Motion.Hosting.Picture.Frames.Error, of keys: [Key]? = nil) -> Motion.Reel<Key>.Error {
            guard case .building(let failure, at: let position) = error,
                let shown = self.position(of: position, among: keys.map { positions(of: $0) }),
                let place = place(of: shown)
            else { return .frames(error) }
            return .building(place.key, failure)
        }
    }

    extension Motion.Reel {
        /// A proof printed of the frames of the parts with these keys, or of the whole reel: every frame on a
        /// sheet or among the stills is drawn once, through `hosting(_:workers:renderer:)`. A sheet is the
        /// raster `Motion.Hosting.Picture.Frames.sheet(_:columns:gap:fill:)` gives for its frames, a still the
        /// frame at full size, and a picture the picture drawn alone at the reel's size over its background,
        /// through the same renderer; each is a PNG of the picture's sRGB pixels, written as
        /// `W3C_PNG::W3C_PNG.Image` of a raster says. A frame beyond the frames printed fails with `.outside` before anything is drawn.
        public func prints(
            _ proof: Proof,
            of keys: [Key]? = nil,
            workers: Cardinal? = nil,
            renderer: Picture::Picture.Renderer? = nil,
            store: Picture::Picture.Store? = nil
        ) async throws(Error) -> Prints {
            let count = keys.map { positions(of: $0).count } ?? Int(clamping: frames)
            let asked = proof.sheets.flatMap(\.frames) + proof.stills
            if let beyond = asked.first(where: { Int(bitPattern: $0) >= count }) { throw .outside(beyond) }
            let drawing = hosting(keys, workers: workers, renderer: renderer, store: store)
            var sizes: [Ordinal: Set<Cardinal>] = [:]
            for sheet in proof.sheets {
                for frame in sheet.frames { sizes[frame, default: []].insert(Swift.max(sheet.columns, 1)) }
            }
            let columns = sizes
            let stills = Set(proof.stills)
            let wanted = Set(asked).sorted()
            let drawn: [Tile]
            do throws(Motion.Hosting.Picture.Frames.Error) {
                drawn = try await drawing.drawn(wanted, as: Tile.form(columns: columns, stills: stills, of: drawing))
            } catch {
                throw failure(error, of: keys)
            }
            let tile = Dictionary(uniqueKeysWithValues: zip(wanted, drawn))
            var sheets: [String: [Byte]] = [:]
            for sheet in proof.sheets {
                let across = Swift.max(sheet.columns, 1)
                let tiles = sheet.frames.compactMap { tile[$0]?.small[across] }
                let raster: Raster<Picture::Picture.Pixel>
                do throws(Raster<Picture::Picture.Pixel>.Error) {
                    raster = try Raster(tiling: tiles, columns: across, gap: sheet.gap, fill: sheet.fill.pixel)
                } catch {
                    throw .sheet(error)
                }
                do throws(W3C_PNG::W3C_PNG.Image.Error) {
                    sheets[sheet.name] = try Motion.Hosting.Picture.Frames.png(raster)
                } catch {
                    throw .png(error)
                }
            }
            var printed: [Ordinal: [Byte]] = [:]
            for still in proof.stills {
                guard let made = tile[still]?.still else { continue }
                do throws(W3C_PNG::W3C_PNG.Image.Error) {
                    printed[still] = try made.get()
                } catch {
                    throw .png(error)
                }
            }
            let names = proof.pictures.keys.sorted()
            let pictures = proof.pictures
            let reel = self
            let alone = Motion.Hosting.Picture.Frames(
                width: width,
                height: height,
                over: background,
                workers: workers,
                renderer: drawing.renderer,
                store: store
            ) { position in reel.scaled(pictures[names[Int(bitPattern: position)]] ?? .empty) }
            let made: [Result<[Byte], W3C_PNG::W3C_PNG.Image.Error>]
            do throws(Motion.Hosting.Picture.Frames.Error) {
                made = try await alone.drawn(names.indices.map { Ordinal(UInt($0)) }, as: .png)
            } catch {
                throw .frames(error)
            }
            var drawnAlone: [String: [Byte]] = [:]
            for (name, result) in zip(names, made) {
                do throws(W3C_PNG::W3C_PNG.Image.Error) {
                    drawnAlone[name] = try result.get()
                } catch {
                    throw .png(error)
                }
            }
            return Prints(sheets: sheets, stills: printed, pictures: drawnAlone)
        }

        /// Every frame of the parts with these keys, or of the whole reel, as PNGs to be asked for one after
        /// another, numbered from zero: a `Feed` that draws a stretch at a time and makes each PNG on the thread
        /// that drew the frame.
        public func sequence(
            _ keys: [Key]? = nil,
            ahead: Cardinal? = nil,
            workers: Cardinal? = nil,
            renderer: Picture::Picture.Renderer? = nil,
            store: Picture::Picture.Store? = nil
        ) -> Motion.Hosting.Picture.Frames.Feed<Result<[Byte], W3C_PNG::W3C_PNG.Image.Error>> {
            let count = Cardinal(UInt(positions(of: keys).count))
            return hosting(keys, workers: workers, renderer: renderer, store: store).feed(first: count, ahead: ahead, as: .png)
        }

        /// Every frame of the parts with these keys, or of the whole reel, as a movie's frames to be asked for
        /// one after another, which is how `Motion.Encoding.write(frames:to:raster:)` asks, and how many there
        /// are.
        public func movie(
            _ keys: [Key]? = nil,
            ahead: Cardinal? = nil,
            workers: Cardinal? = nil,
            renderer: Picture::Picture.Renderer? = nil,
            store: Picture::Picture.Store? = nil
        ) -> (frames: Cardinal, feed: Motion.Hosting.Picture.Frames.Feed<Raster<Motion.Pixel>>) {
            let count = Cardinal(UInt(positions(of: keys).count))
            return (count, hosting(keys, workers: workers, renderer: renderer, store: store).feed(first: count, ahead: ahead))
        }

        /// The frames of the parts with these keys, or of the whole reel, shown at these instants in seconds from
        /// their start, in the order given: the frame at `rate.index(at:)` of each, drawn as `hosting(_:workers:renderer:)`
        /// draws it, and nil for an instant before zero or from the end of the frames on. It is how a reel drawn
        /// directly is set beside a movie in `Motion.Pairs`.
        public func frames(
            at instants: [Rational],
            of keys: [Key]? = nil,
            workers: Cardinal? = nil,
            renderer: Picture::Picture.Renderer? = nil,
            store: Picture::Picture.Store? = nil
        ) async throws(Motion.Hosting.Picture.Frames.Error) -> [Raster<Motion.Pixel>?] {
            let count = keys.map { positions(of: $0).count } ?? Int(clamping: frames)
            let places: [Ordinal?] = instants.map { instant in
                guard instant >= .zero, let index = rate.index(at: instant).exactly(Int.self), index < count else { return nil }
                return Ordinal(UInt(index))
            }
            let wanted = Swift.Array(Set(places.compactMap { $0 })).sorted()
            let drawn = try await hosting(keys, workers: workers, renderer: renderer, store: store).rasters(wanted)
            let shown = Dictionary(uniqueKeysWithValues: zip(wanted, drawn))
            return places.map { place in place.flatMap { shown[$0] } }
        }

    }
#endif
