import Foundation

/// Reads fields out of an ISO BMFF file by finding a box's four-character type.
struct Box {
    let bytes: [UInt8]

    init(_ url: URL) throws {
        bytes = [UInt8](try Data(contentsOf: url))
    }

    func offset(of type: String) -> Int? {
        let tag = Array(type.utf8)
        return bytes.indices.dropLast(4).first { bytes[$0..<$0 + 4].elementsEqual(tag) }
    }

    func integer(at offset: Int, bytes count: Int) -> Int {
        bytes[offset..<offset + count].reduce(0) { $0 << 8 | Int($1) }
    }

    /// The `nclx` colour of the first `colr` box: primaries-transfer-matrix and the full-range flag.
    var colour: (codes: String, full: Bool)? {
        guard let at = offset(of: "colr"), bytes[at + 4..<at + 8].elementsEqual(Array("nclx".utf8)) else { return nil }
        let codes = "\(integer(at: at + 8, bytes: 2))-\(integer(at: at + 10, bytes: 2))-\(integer(at: at + 12, bytes: 2))"
        return (codes, bytes[at + 14] & 0x80 != 0)
    }

    /// The timescale of a version 0 `mvhd` or `mdhd` box.
    func timescale(_ type: String) -> Int? { offset(of: type).map { integer(at: $0 + 16, bytes: 4) } }

    /// The first `stts` entry: how many samples last how many ticks.
    var durations: (count: Int, ticks: Int)? {
        offset(of: "stts").map { (integer(at: $0 + 12, bytes: 4), integer(at: $0 + 16, bytes: 4)) }
    }
}
