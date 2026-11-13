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

            public init(
                _ action: Action = .sheet,
                output: Swift.String = "",
                parts: [Swift.String] = [],
                at: [Ordinal] = [],
                stills: [Ordinal] = [],
                columns: Cardinal = 5
            ) {
                self.action = action
                self.output = output
                self.parts = parts
                self.at = at
                self.stills = stills
                self.columns = columns
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
                    help: .init(abstract: "sheet, frames or movie."),
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
            }
        }

        /// Parts joined by commas count as parts given one by one.
        public mutating func validate() throws(Command_Primitive::Command.Error) {
            parts = parts.flatMap { $0.split(separator: ",").map(Swift.String.init) }
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

        @Sendable static func count(_ text: Swift.String) throws(Command_Primitive::Command.Error) -> Cardinal {
            guard let count = UInt(text), count > 0 else { throw .validationFailed(reason: "no count \(text)") }
            return Cardinal(count)
        }
    }
#endif
