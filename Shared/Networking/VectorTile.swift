import Foundation
import CoreGraphics

/// A bounded reader for the public Mapbox Vector Tile 2.x protobuf format.
/// Only Shortbread layers used by this renderer are retained. Unknown fields and
/// unused layers are skipped; malformed data is rejected before reaching AppKit.
struct VectorTile {
    struct Feature {
        let layer: String
        let kind: String
        let name: String
        let type: Int
        let paths: [[CGPoint]] // tile-local pixels, south-positive, 256-pixel tile
    }
    let features: [Feature]
    static let maximumBytes = 2_000_000
    private static let layers: Set<String> = ["streets", "street_labels", "ocean", "water_polygons", "water_lines", "land", "sites", "pois", "public_transport"]
    static func decode(_ data: Data) -> VectorTile? {
        guard !data.isEmpty, data.count <= maximumBytes else { return nil }
        do {
            var reader = ProtoReader(data), features: [Feature] = [], layerCount = 0, pointBudget = 100_000
            while !reader.atEnd {
                let (field, wire) = try reader.tag()
                if field == 3 && wire == 2 {
                    layerCount += 1; guard layerCount <= 100 else { throw ProtoError.invalid }
                    features += try decodeLayer(reader.message(), pointBudget: &pointBudget)
                } else { try reader.skip(wire) }
            }
            guard layerCount > 0 else { return nil }
            return VectorTile(features: features)
        } catch { return nil }
    }
    private static func decodeLayer(_ bytes: Data, pointBudget: inout Int) throws -> [Feature] {
        var r = ProtoReader(bytes), name = "", extent = 4096, version = 1
        var raw: [Data] = [], keys: [String] = [], values: [String] = []
        while !r.atEnd {
            let (field, wire) = try r.tag()
            switch (field, wire) {
            case (1, 2): name = try r.string()
            case (2, 2): raw.append(try r.message())
            case (3, 2): keys.append(try r.string())
            case (4, 2): values.append(try value(r.message()))
            case (5, 0): extent = try r.number()
            case (15, 0): version = try r.number()
            default: try r.skip(wire)
            }
            guard raw.count <= 20_000, keys.count <= 10_000, values.count <= 40_000 else { throw ProtoError.invalid }
        }
        guard !name.isEmpty, (1...2).contains(version), (1...65_536).contains(extent) else { throw ProtoError.invalid }
        guard layers.contains(name) else { return [] }
        var result: [Feature] = []
        for bytes in raw {
            var f = ProtoReader(bytes), tags: [Int] = [], commands: [Int] = [], type = 0
            while !f.atEnd {
                let (field, wire) = try f.tag()
                switch (field, wire) {
                case (2, 2): tags += try packed(f.message())
                case (2, 0): tags.append(try f.number())
                case (3, 0): type = try f.number()
                case (4, 2): commands += try packed(f.message())
                case (4, 0): commands.append(try f.number())
                default: try f.skip(wire)
                }
            }
            guard tags.count % 2 == 0, (1...3).contains(type) else { throw ProtoError.invalid }
            var properties: [String: String] = [:]
            for index in stride(from: 0, to: tags.count, by: 2) {
                guard tags[index] < keys.count, tags[index + 1] < values.count else { throw ProtoError.invalid }
                properties[keys[tags[index]]] = values[tags[index + 1]]
            }
            if name == "streets", properties["rail"] == "true" { continue }
            let geometry = try paths(commands, type: type, extent: extent, budget: &pointBudget)
            result.append(Feature(layer: name, kind: properties["kind"] ?? "", name: properties["name"] ?? properties["name_en"] ?? "", type: type, paths: geometry))
        }
        return result
    }
    private static func value(_ bytes: Data) throws -> String {
        var r = ProtoReader(bytes), result = ""
        while !r.atEnd {
            let (field, wire) = try r.tag()
            if field == 1 && wire == 2 { result = try r.string() }
            else if field == 7 && wire == 0 { result = try r.number() == 0 ? "false" : "true" }
            else { try r.skip(wire) } // Numeric attributes are not used by this style.
        }
        return result
    }
    private static func packed(_ bytes: Data) throws -> [Int] {
        var r = ProtoReader(bytes), values: [Int] = []
        while !r.atEnd { values.append(try r.number()); guard values.count <= 300_000 else { throw ProtoError.invalid } }
        return values
    }
    private static func paths(_ commands: [Int], type: Int, extent: Int, budget: inout Int) throws -> [[CGPoint]] {
        var index = 0, x = 0, y = 0, result: [[CGPoint]] = [], current: [CGPoint] = []
        func flush() throws {
            guard current.count >= (type == 1 ? 1 : type == 2 ? 2 : 4) else { throw ProtoError.invalid }
            result.append(current); current = []
        }
        while index < commands.count {
            let command = commands[index] & 7, count = commands[index] >> 3; index += 1
            guard count > 0 else { throw ProtoError.invalid }
            if command == 7 {
                guard type == 3, count == 1, current.count >= 3 else { throw ProtoError.invalid }
                current.append(current[0]); try flush(); continue
            }
            guard command == 1 || command == 2, count <= (commands.count - index) / 2,
                  count <= budget, !(type == 1 && command == 2), command != 2 || !current.isEmpty else { throw ProtoError.invalid }
            if command == 1 && type != 1 && count != 1 { throw ProtoError.invalid }
            budget -= count
            for _ in 0..<count {
                if command == 1 && !current.isEmpty {
                    guard type != 3 else { throw ProtoError.invalid }; try flush()
                }
                let a = commands[index], b = commands[index + 1]; index += 2
                x += (a >> 1) ^ -(a & 1); y += (b >> 1) ^ -(b & 1)
                guard abs(x) <= extent * 16, abs(y) <= extent * 16 else { throw ProtoError.invalid }
                current.append(CGPoint(x: Double(x) * 256 / Double(extent), y: Double(y) * 256 / Double(extent)))
            }
        }
        if !current.isEmpty { guard type != 3 else { throw ProtoError.invalid }; try flush() }
        guard !result.isEmpty else { throw ProtoError.invalid }
        return result
    }
}

private enum ProtoError: Error { case invalid }
private struct ProtoReader {
    private let bytes: [UInt8]
    private var index = 0
    init(_ data: Data) { bytes = Array(data) }
    var atEnd: Bool { index == bytes.count }
    mutating func varint() throws -> UInt64 {
        var value: UInt64 = 0
        for shift in stride(from: 0, through: 63, by: 7) {
            guard index < bytes.count else { throw ProtoError.invalid }
            let byte = bytes[index]; index += 1
            guard shift != 63 || byte <= 1 else { throw ProtoError.invalid }
            value |= UInt64(byte & 127) << shift
            if byte & 128 == 0 { return value }
        }
        throw ProtoError.invalid
    }
    mutating func number() throws -> Int {
        let value = try varint(); guard value <= UInt32.max else { throw ProtoError.invalid }; return Int(value)
    }
    mutating func tag() throws -> (Int, Int) {
        let tag = try number(); guard tag >> 3 > 0 else { throw ProtoError.invalid }; return (tag >> 3, tag & 7)
    }
    mutating func message() throws -> Data {
        let size = try number(); guard size <= bytes.count - index else { throw ProtoError.invalid }
        defer { index += size }; return Data(bytes[index..<(index + size)])
    }
    mutating func string() throws -> String {
        let data = try message(); guard data.count <= 65_536, let string = String(data: data, encoding: .utf8) else { throw ProtoError.invalid }; return string
    }
    mutating func skip(_ wire: Int) throws {
        switch wire {
        case 0: _ = try varint()
        case 1, 5:
            let count = wire == 1 ? 8 : 4; guard count <= bytes.count - index else { throw ProtoError.invalid }; index += count
        case 2: _ = try message()
        default: throw ProtoError.invalid
        }
    }
}
