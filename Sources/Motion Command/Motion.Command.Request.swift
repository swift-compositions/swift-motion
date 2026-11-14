#if Command
    public import Command
    public import Motion

    extension Motion.Command {
        /// What a command was asked to write: the action, the directory it writes into, the parts whose frames
        /// it writes, and for sheets the frames chosen for one sheet and for stills, and how many to a row.
        ///
        /// Frames are counted among the frames of the chosen parts, played one after another: for one part, the
        /// part's own frames; for none, the reel's.
        public struct Request: Sendable, Equatable {
            public var action: Action
            public var output: Swift.String
            public var parts: [Swift.String]
            public var at: [Ordinal]
            public var stills: [Ordinal]
            public var columns: Cardinal
            /// For compare: the movie the reel is set beside, on the left.
            public var reference: Swift.String
            /// For compare: the time between one pair and the next.
            public var step: Rational
            /// For compare: how many pairs to a sheet.
            public var pairs: Cardinal
            /// For compare: a frame's width on a sheet; its height keeps the reference's shape.
            public var width: Cardinal
            /// For compare: a font file the instants are written in, or empty for no labels.
            public var font: Swift.String
            /// For sheet: the names of proofs of the whole reel to write.
            public var proofs: [Swift.String]
            /// The keys of the layers to draw, by name; empty for every layer.
            public var layers: [Swift.String]
            /// Whether to draw the reel without any layer.
            public var bare: Bool
            /// Values for the maker of the film, each `<name>=<value>`.
            public var settings: [Swift.String]
            /// A directory drawn frames are kept in and read back from, or empty to draw every frame.
            public var cache: Swift.String
            /// How large the reel is drawn: 1 at its own size, 0.5 as a draft of half the width and height.
            public var scale: Double
            /// For movie: a sound file laid under the movie as it is written, or empty for a silent movie.
            public var sound: Swift.String
            /// For movie with a sound: where in the sound it starts.
            public var offset: Rational
            /// For movie with a sound: the level it plays at, as a multiple of its own.
            public var gain: Float
            /// For movie with a sound: how long it takes to rise from silence.
            public var rise: Rational
            /// For movie with a sound: how long it takes to fall to silence at its end.
            public var fall: Rational

            public init(
                _ action: Action = .sheet,
                output: Swift.String = "",
                parts: [Swift.String] = [],
                at: [Ordinal] = [],
                stills: [Ordinal] = [],
                columns: Cardinal = 5,
                reference: Swift.String = "",
                step: Rational = .half,
                pairs: Cardinal = 10,
                width: Cardinal = 480,
                font: Swift.String = "",
                proofs: [Swift.String] = [],
                layers: [Swift.String] = [],
                bare: Bool = false,
                settings: [Swift.String] = [],
                cache: Swift.String = "",
                scale: Double = 1,
                sound: Swift.String = "",
                offset: Rational = .zero,
                gain: Float = 1,
                rise: Rational = .zero,
                fall: Rational = .zero
            ) {
                self.action = action
                self.output = output
                self.parts = parts
                self.at = at
                self.stills = stills
                self.columns = columns
                self.reference = reference
                self.step = step
                self.pairs = pairs
                self.width = width
                self.font = font
                self.proofs = proofs
                self.layers = layers
                self.bare = bare
                self.settings = settings
                self.cache = cache
                self.scale = scale
                self.sound = sound
                self.offset = offset
                self.gain = gain
                self.rise = rise
                self.fall = fall
            }
        }
    }

    extension Motion.Command.Request: Command_Primitive::Command.`Protocol` {
        public static var configuration: Command_Primitive::Command.Configuration {
            Command_Primitive::Command.Configuration(
                name: "reel",
                abstract: "Writes proofs of a reel: contact sheets and stills, every frame, or a movie."
            )
        }

        public static var schema: Command_Primitive::Command.Schema.Definition<Self> {
            Command_Primitive::Command.Schema.Definition<Self> {
                Command_Primitive::Command.Positional(
                    \.action,
                    name: "action",
                    help: .init(abstract: "sheet or frames, and where AVFoundation is, movie or compare."),
                    transform: Self.action
                )
                Command_Primitive::Command.Positional(
                    \.output,
                    name: "output",
                    help: .init(abstract: "The directory written into.")
                )
                Command_Primitive::Command.Option.Many(
                    \.parts,
                    name: .long(.literal("part")),
                    help: .init(abstract: "The parts whose frames are written, in this order; commas may join several.")
                )
                Command_Primitive::Command.Option(
                    \.at,
                    name: .long(.literal("at")),
                    help: .init(abstract: "For sheet: the frames of one sheet, with commas between."),
                    transform: Self.frames
                )
                Command_Primitive::Command.Option(
                    \.stills,
                    name: .long(.literal("stills")),
                    help: .init(abstract: "For sheet: the frames written at full size, with commas between."),
                    transform: Self.frames
                )
                Command_Primitive::Command.Option(
                    \.columns,
                    name: .long(.literal("columns")),
                    help: .init(abstract: "For sheet with --at: how many frames to a row.", defaults: "5"),
                    transform: Self.count
                )
                Command_Primitive::Command.Option(
                    \.reference,
                    name: .long(.literal("reference")),
                    help: .init(abstract: "For compare: the movie the reel is set beside.")
                )
                Command_Primitive::Command.Option(
                    \.step,
                    name: .long(.literal("step")),
                    help: .init(abstract: "For compare: seconds from one pair to the next.", defaults: "0.5"),
                    transform: Self.seconds
                )
                Command_Primitive::Command.Option(
                    \.pairs,
                    name: .long(.literal("pairs")),
                    help: .init(abstract: "For compare: pairs to a sheet.", defaults: "10"),
                    transform: Self.count
                )
                Command_Primitive::Command.Option(
                    \.width,
                    name: .long(.literal("width")),
                    help: .init(abstract: "For compare: a frame's width on a sheet, in pixels.", defaults: "480"),
                    transform: Self.count
                )
                Command_Primitive::Command.Option(
                    \.font,
                    name: .long(.literal("font")),
                    help: .init(abstract: "For compare: a TrueType or OpenType font file the instants are written in; without it, no labels.")
                )
                Command_Primitive::Command.Option.Many(
                    \.proofs,
                    name: .long(.literal("proof")),
                    help: .init(abstract: "For sheet: the proofs of the whole reel to write; commas may join several.")
                )
                Command_Primitive::Command.Option.Many(
                    \.layers,
                    name: .long(.literal("layer")),
                    help: .init(abstract: "The layers to draw, by key, and no other; commas may join several.")
                )
                Command_Primitive::Command.Flag(
                    \.bare,
                    name: .long(.literal("bare")),
                    help: .init(abstract: "Draw the reel without any layer.")
                )
                Command_Primitive::Command.Option.Many(
                    \.settings,
                    name: .long(.literal("set")),
                    help: .init(abstract: "A value for the film's maker, as <name>=<value>; may be given more than once.")
                )
                Command_Primitive::Command.Option(
                    \.cache,
                    name: .long(.literal("cache")),
                    help: .init(abstract: "A directory drawn frames are kept in and read back from by later runs; without it, every frame is drawn.")
                )
                Command_Primitive::Command.Option(
                    \.scale,
                    name: .long(.literal("scale")),
                    help: .init(abstract: "Draw the reel this many times its size, such as 0.5 for a draft.", defaults: "1"),
                    transform: Self.factor
                )
                Command_Primitive::Command.Option(
                    \.sound,
                    name: .long(.literal("sound")),
                    help: .init(abstract: "For movie: a sound file laid under the movie as it is written, cut where the movie ends.")
                )
                Command_Primitive::Command.Option(
                    \.offset,
                    name: .long(.literal("offset")),
                    help: .init(abstract: "For movie with --sound: seconds into the sound where it starts.", defaults: "0"),
                    transform: Self.seconds
                )
                Command_Primitive::Command.Option(
                    \.gain,
                    name: .long(.literal("gain")),
                    help: .init(abstract: "For movie with --sound: the sound's level as a multiple of its own.", defaults: "1"),
                    transform: Self.gain
                )
                Command_Primitive::Command.Option(
                    \.rise,
                    name: .long(.literal("fade-in")),
                    help: .init(abstract: "For movie with --sound: seconds the sound takes to rise from silence.", defaults: "0"),
                    transform: Self.seconds
                )
                Command_Primitive::Command.Option(
                    \.fall,
                    name: .long(.literal("fade-out")),
                    help: .init(abstract: "For movie with --sound: seconds the sound takes to fall to silence at its end.", defaults: "0"),
                    transform: Self.seconds
                )
            }
        }

        /// Parts, proofs and layers joined by commas count as given one by one, a setting needs its `=`,
        /// compare needs a reference, and a sound is for movie alone.
        public mutating func validate() throws(Command_Primitive::Command.Error) {
            parts = parts.flatMap { $0.split(separator: ",").map(Swift.String.init) }
            proofs = proofs.flatMap { $0.split(separator: ",").map(Swift.String.init) }
            layers = layers.flatMap { $0.split(separator: ",").map(Swift.String.init) }
            if let setting = settings.first(where: { !$0.contains("=") }) {
                throw .validationFailed(reason: "no setting \(setting): <name>=<value>")
            }
            #if canImport(AVFoundation)
                if action == .compare, reference.isEmpty { throw .validationFailed(reason: "compare needs --reference") }
                let sounding = action == .movie
            #else
                let sounding = false
            #endif
            if !sound.isEmpty, !sounding { throw .validationFailed(reason: "--sound is for movie") }
        }

        /// A request is read and not run: `Motion.Command.run(_:_:proofs:)` acts on it with a reel.
        public mutating func run() async throws(Command_Primitive::Command.Error) {}
    }

    extension Motion.Command.Request {
        /// The value given for a name with `--set <name>=<value>`, the last one when given more than once, or nil.
        public func value(_ name: Swift.String) -> Swift.String? {
            settings.last { $0.hasPrefix(name + "=") }.map { Swift.String($0.dropFirst(name.count + 1)) }
        }

        /// A request read from a command line's arguments, without the executable's name.
        public static func parse(_ arguments: [Swift.String]) throws(Command_Primitive::Command.Error) -> Self {
            try Command_Primitive::Command.parse(Self.self, from: arguments, initial: Self())
        }

        /// The help a command prints when asked with `--help`.
        public static var help: Swift.String {
            var text = ""
            Command_Primitive::Command.Help<Self>().serialize(schema, into: &text)
            return text
        }

        @Sendable static func action(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Motion.Command.Action {
            guard let action = Motion.Command.Action(rawValue: text) else { throw .validationFailed(reason: "no action \(text)") }
            return action
        }

        @Sendable static func frames(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> [Ordinal] {
            try text.split(separator: ",").map { item throws(Command_Primitive::Command.Error) in
                guard let frame = UInt(item) else { throw .validationFailed(reason: "no frame \(item)") }
                return Ordinal(frame)
            }
        }

        /// Seconds written as a whole number, a decimal or a fraction, never below zero, as `Rational.init?(_:)`
        /// reads them: `1`, `0.5`, `1001/30000`.
        @Sendable static func seconds(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Rational {
            guard let seconds = Rational(text), seconds >= .zero else { throw .validationFailed(reason: "no seconds \(text)") }
            return seconds
        }

        /// A scale: a decimal number above zero, such as `0.5`.
        @Sendable static func factor(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Double {
            guard let factor = Double(text), factor > 0, factor.isFinite else { throw .validationFailed(reason: "no scale \(text)") }
            return factor
        }

        /// A level: a decimal number, zero or above, such as `0.32`.
        @Sendable static func gain(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Float {
            guard let gain = Float(text), gain.isFinite, gain >= 0 else { throw .validationFailed(reason: "no gain \(text)") }
            return gain
        }

        @Sendable static func count(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Cardinal {
            guard let count = UInt(text), count > 0 else { throw .validationFailed(reason: "no count \(text)") }
            return Cardinal(count)
        }
    }
#endif
