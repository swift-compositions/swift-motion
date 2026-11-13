#if Command && canImport(AVFoundation)
    public import Command
    public import Motion
    public import Motion_Encoding

    extension Motion.Command {
        /// What the command line over movie files was asked, which needs no reel: the action, its files, and
        /// the options of each action.
        ///
        ///     motion compare <reference> <movie> <output> [--step <s>] [--pairs <count>] [--width <pixels>] [--font <file>]
        ///     motion score <movie> <sound> <output> [--offset <s>] [--at <s>] [--gain <g>] [--fade-in <s>] [--fade-out <s>]
        ///     motion reduce <movie> <output> [--height 540|720|1080]
        ///
        /// Times are seconds, written as a whole number, a decimal or a fraction: `1`, `0.5`, `1001/30000`.
        public struct Movies: Sendable, Equatable {
            public var action: Action
            /// The files: three for `compare` and `score`, two for `reduce`, the output last.
            public var files: [Swift.String]
            /// For compare: the time between one pair and the next.
            public var step: Rational
            /// For compare: how many pairs to a sheet.
            public var pairs: Cardinal
            /// For compare: a frame's width on a sheet; its height keeps the reference's shape.
            public var width: Cardinal
            /// For compare: a font file the instants are written in, or empty for no labels.
            public var font: Swift.String
            /// For score: where in the sound it starts.
            public var offset: Rational
            /// For score: the film time at which the sound enters.
            public var at: Rational
            /// For score: the level the sound plays at, as a multiple of its own.
            public var gain: Float
            /// For score: how long the sound takes to rise from silence.
            public var fadeIn: Rational
            /// For score: how long the sound takes to fall to silence at its end.
            public var fadeOut: Rational
            /// For reduce: the size the movie is made smaller to.
            public var preset: Motion.Encoding.Preset

            public init(
                _ action: Action = .compare,
                files: [Swift.String] = [],
                step: Rational = Motion.Command.Request.half,
                pairs: Cardinal = 10,
                width: Cardinal = 480,
                font: Swift.String = "",
                offset: Rational = .zero,
                at: Rational = .zero,
                gain: Float = 1,
                fadeIn: Rational = .zero,
                fadeOut: Rational = .zero,
                preset: Motion.Encoding.Preset = .height720
            ) {
                self.action = action
                self.files = files
                self.step = step
                self.pairs = pairs
                self.width = width
                self.font = font
                self.offset = offset
                self.at = at
                self.gain = gain
                self.fadeIn = fadeIn
                self.fadeOut = fadeOut
                self.preset = preset
            }
        }
    }

    extension Motion.Command.Movies: Command_Primitive::Command.`Protocol` {
        public static var configuration: Command_Primitive::Command.Configuration {
            Command_Primitive::Command.Configuration(
                name: "motion",
                abstract: "Compares two movies side by side, lays a sound under a movie, or makes a movie smaller."
            )
        }

        public static var schema: Command_Primitive::Command.Schema.Definition<Self> {
            Command_Primitive::Command.Schema.Definition<Self> {
                Command_Primitive::Command.Positional(
                    \.action,
                    name: "action",
                    help: .init(abstract: "compare, score or reduce."),
                    transform: Self.action
                )
                Command_Primitive::Command.Positional.Many(
                    \.files,
                    name: "files",
                    help: .init(abstract: "compare: reference, movie, directory. score: movie, sound, movie written. reduce: movie, movie written.")
                )
                Command_Primitive::Command.Option(
                    \.step,
                    name: .long(.literal("step")),
                    help: .init(abstract: "For compare: seconds from one pair to the next.", defaults: "0.5"),
                    transform: Motion.Command.Request.seconds
                )
                Command_Primitive::Command.Option(
                    \.pairs,
                    name: .long(.literal("pairs")),
                    help: .init(abstract: "For compare: pairs to a sheet.", defaults: "10"),
                    transform: Motion.Command.Request.count
                )
                Command_Primitive::Command.Option(
                    \.width,
                    name: .long(.literal("width")),
                    help: .init(abstract: "For compare: a frame's width on a sheet, in pixels.", defaults: "480"),
                    transform: Motion.Command.Request.count
                )
                Command_Primitive::Command.Option(
                    \.font,
                    name: .long(.literal("font")),
                    help: .init(abstract: "For compare: a TrueType or OpenType font file the instants are written in; without it, no labels.")
                )
                Command_Primitive::Command.Option(
                    \.offset,
                    name: .long(.literal("offset")),
                    help: .init(abstract: "For score: seconds into the sound where it starts.", defaults: "0"),
                    transform: Motion.Command.Request.seconds
                )
                Command_Primitive::Command.Option(
                    \.at,
                    name: .long(.literal("at")),
                    help: .init(abstract: "For score: the film time in seconds at which the sound enters.", defaults: "0"),
                    transform: Motion.Command.Request.seconds
                )
                Command_Primitive::Command.Option(
                    \.gain,
                    name: .long(.literal("gain")),
                    help: .init(abstract: "For score: the sound's level as a multiple of its own.", defaults: "1"),
                    transform: Self.gain
                )
                Command_Primitive::Command.Option(
                    \.fadeIn,
                    name: .long(.literal("fade-in")),
                    help: .init(abstract: "For score: seconds the sound takes to rise from silence.", defaults: "0"),
                    transform: Motion.Command.Request.seconds
                )
                Command_Primitive::Command.Option(
                    \.fadeOut,
                    name: .long(.literal("fade-out")),
                    help: .init(abstract: "For score: seconds the sound takes to fall to silence at its end.", defaults: "0"),
                    transform: Motion.Command.Request.seconds
                )
                Command_Primitive::Command.Option(
                    \.preset,
                    name: .long(.literal("height")),
                    help: .init(abstract: "For reduce: 540, 720 or 1080.", defaults: "720"),
                    transform: Self.preset
                )
            }
        }

        /// `compare` and `score` take three files and `reduce` two.
        public mutating func validate() throws(Command_Primitive::Command.Error) {
            let needed = action == .reduce ? 2 : 3
            guard files.count == needed else {
                throw .validationFailed(reason: "\(action.rawValue) takes \(needed) files, not \(files.count)")
            }
        }

        /// A request is read and not run: `Motion.Command.run(_:)` acts on it.
        public mutating func run() async throws(Command_Primitive::Command.Error) {}
    }

    extension Motion.Command.Movies {
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

        @Sendable static func action(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Action {
            guard let action = Action(rawValue: text) else { throw .validationFailed(reason: "no action \(text)") }
            return action
        }

        @Sendable static func gain(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Float {
            guard let gain = Float(text), gain.isFinite, gain >= 0 else { throw .validationFailed(reason: "no gain \(text)") }
            return gain
        }

        @Sendable static func preset(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Motion.Encoding.Preset {
            guard let preset = Motion.Encoding.Preset(rawValue: text) else { throw .validationFailed(reason: "no height \(text): 540, 720 or 1080") }
            return preset
        }
    }
#endif
