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

            public init(
                _ action: Action = .sheet,
                output: Swift.String = "",
                parts: [Swift.String] = [],
                at: [Ordinal] = [],
                stills: [Ordinal] = [],
                columns: Cardinal = 5,
                reference: Swift.String = "",
                step: Rational = Self.half,
                pairs: Cardinal = 10,
                width: Cardinal = 480,
                font: Swift.String = ""
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
                    help: .init(abstract: "sheet, frames, movie or compare."),
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
            }
        }

        /// Parts joined by commas count as parts given one by one, and compare needs a reference.
        public mutating func validate() throws(Command_Primitive::Command.Error) {
            parts = parts.flatMap { $0.split(separator: ",").map(Swift.String.init) }
            if action == .compare, reference.isEmpty { throw .validationFailed(reason: "compare needs --reference") }
        }

        /// A request is read and not run: `Motion.Command.run(_:_:proofs:)` acts on it with a reel.
        public mutating func run() async throws(Command_Primitive::Command.Error) {}
    }

    extension Motion.Command.Request {
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

        /// Seconds written as a whole number, a decimal or a fraction, never below zero: `1`, `0.5`, `1001/30000`.
        @Sendable static func seconds(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Rational {
            let parts = text.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count == 1, let exact = Rational(text), exact >= .zero { return exact }
            guard parts.count == 2, !parts[0].isEmpty || !parts[1].isEmpty, (parts[0] + parts[1]).allSatisfy(\.isASCII),
                let digits = Integer(Swift.String(parts[0] + parts[1])), !digits.isNegative,
                (parts[0] + parts[1]).allSatisfy(\.isWholeNumber)
            else { throw .validationFailed(reason: "no seconds \(text)") }
            do throws(Rational.Error) {
                return try Rational(numerator: digits, denominator: parts[1].reduce(Integer.one) { power, _ in power * 10 })
            } catch {
                throw .validationFailed(reason: "no seconds \(text)")
            }
        }

        /// Half a second.
        public static var half: Rational {
            do throws(Rational.Error) {
                return try Rational(numerator: 1, denominator: 2)
            } catch {
                preconditionFailure("two is not zero")
            }
        }

        @Sendable static func count(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Cardinal {
            guard let count = UInt(text), count > 0 else { throw .validationFailed(reason: "no count \(text)") }
            return Cardinal(count)
        }
    }
#endif
