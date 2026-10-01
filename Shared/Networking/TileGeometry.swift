import Foundation

struct TileID: Hashable, Codable {
    let z: Int; let x: Int; let y: Int
    init?(z: Int, x: Int, y: Int) {
        guard (0...19).contains(z), (0..<(1 << z)).contains(y) else { return nil }
        self.z = z; self.x = ((x % (1 << z)) + (1 << z)) % (1 << z); self.y = y
    }
    var key: String { "\(z)-\(x)-\(y)" }
}
struct TilePlacement: Equatable {
    let id: TileID
    let x: Int; let y: Int
}
enum Mercator {
    static func point(latitude: Double, longitude: Double, zoom: Int) -> CGPoint {
        let lat = min(85.05112878, max(-85.05112878, latitude)) * .pi / 180
        let n = Double(1 << max(0, min(19, zoom)))
        let lon = ((longitude + 180).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return CGPoint(x: lon / 360 * n * 256, y: (1 - asinh(tan(lat)) / .pi) / 2 * n * 256)
    }
    static func viewport(center: CGPoint, size: CGSize, zoom: Int) -> [TilePlacement] {
        guard size.width > 0, size.height > 0, size.width <= 2048, size.height <= 1280 else { return [] }
        let left = Int(floor((center.x - size.width / 2) / 256))
        let right = Int(floor((center.x + size.width / 2 - 0.001) / 256))
        let top = Int(floor((center.y - size.height / 2) / 256))
        let bottom = Int(floor((center.y + size.height / 2 - 0.001) / 256))
        return (top...bottom).flatMap { y in (left...right).compactMap { x in
            TileID(z: zoom, x: x, y: y).map { TilePlacement(id: $0, x: x, y: y) }
        } }
    }
    static func renderSize(_ size: CGSize) -> CGSize {
        let scale = min(1, 1792 / max(1, size.width), 1120 / max(1, size.height))
        return CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
    }
    static func drift(_ time: Double) -> CGPoint {
        CGPoint(x: 80 * sin(time / 110), y: 55 * sin(time / 143))
    }
}

struct TileProvider {
    let template: String
    let cacheNamespace: String
    let attribution: String
    static let osm = TileProvider(template: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", cacheNamespace: "osm-standard", attribution: "© OpenStreetMap contributors")
    func url(_ id: TileID) -> URL? {
        let text = template.replacingOccurrences(of: "{z}", with: String(id.z)).replacingOccurrences(of: "{x}", with: String(id.x)).replacingOccurrences(of: "{y}", with: String(id.y))
        guard let url = URL(string: text), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}
