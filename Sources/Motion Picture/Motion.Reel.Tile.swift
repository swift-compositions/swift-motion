#if Picture
    import Binary
    import Byte
    import Motion
    import Picture
    import Picture_PNG_Integration

    extension Motion.Reel {
        /// What is kept of a frame drawn for a proof: a small copy for each number of columns of the sheets it is
        /// on, and its PNG where it is a still.
        struct Tile: Sendable {
            let small: [Cardinal: Raster<Picture::Picture.Pixel>]
            let still: Result<[Byte], W3C_PNG::W3C_PNG.Image.Error>?
        }
    }

    extension Motion.Reel.Tile {
        /// The form a proof's frame is drawn as: named by the numbers of columns it is made small for and whether it
        /// is a still, and kept as each small copy's working pixels and the still's PNG.
        static func form(
            columns: [Ordinal: Set<Cardinal>],
            stills: Set<Ordinal>,
            of drawing: Motion.Hosting.Picture.Frames
        ) -> Motion.Hosting.Picture.Frames.Form<Self> {
            typealias Frames = Motion.Hosting.Picture.Frames
            return Frames.Form(
                name: { position in
                    let across = (columns[position] ?? []).sorted().map { Swift.String(Int(clamping: $0)) }.joined(separator: ",")
                    return "proof tile " + across + (stills.contains(position) ? " still" : "")
                },
                make: { position, raster in
                    let small = (columns[position] ?? []).map { across in
                        let size = drawing.tile(columns: across)
                        return (across, Frames.shrunk(raster, width: size.width, height: size.height))
                    }
                    return Self(
                        small: Dictionary(uniqueKeysWithValues: small),
                        still: stills.contains(position) ? Result { () throws(W3C_PNG::W3C_PNG.Image.Error) in try Frames.png(raster) } : nil
                    )
                },
                bytes: { tile in
                    var bytes: [Byte] = []
                    UInt64(tile.small.count).bytes(into: &bytes, endianness: .little)
                    for across in tile.small.keys.sorted() {
                        guard let raster = tile.small[across] else { return nil }
                        UInt64(Int(clamping: across)).bytes(into: &bytes, endianness: .little)
                        bytes += Frames.working(raster)
                    }
                    switch tile.still {
                    case nil:
                        bytes.append(Byte(bitPattern: 0))
                    case .success(let png):
                        bytes.append(Byte(bitPattern: 1))
                        bytes += png
                    case .failure:
                        return nil
                    }
                    return bytes
                },
                frame: { bytes in
                    let count = Frames.number(bytes, at: 0)
                    guard count <= 1 << 16 else { return nil }
                    var offset = 8
                    var small: [Cardinal: Raster<Picture::Picture.Pixel>] = [:]
                    for _ in 0..<Int(count) {
                        let across = Frames.number(bytes, at: offset)
                        guard across < 1 << 32, let (raster, end) = Frames.working(bytes, from: offset + 8) else { return nil }
                        small[Cardinal(UInt(across))] = raster
                        offset = end
                    }
                    guard offset < bytes.count else { return nil }
                    let still: Result<[Byte], W3C_PNG::W3C_PNG.Image.Error>?
                    switch bytes[offset].bitPattern {
                    case 0 where offset == bytes.indices.last: still = nil
                    case 1: still = .success(Array(bytes[(offset + 1)...]))
                    default: return nil
                    }
                    return Self(small: small, still: still)
                }
            )
        }
    }
#endif
