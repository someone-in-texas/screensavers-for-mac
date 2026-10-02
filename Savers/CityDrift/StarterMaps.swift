import AppKit
import QuartzCore

private final class StarterResourceBundle: NSObject {}

struct StarterMap: Decodable {
    struct Road: Decodable { let kind: String; let points: [[Double]] }
    let name: String
    let zoom: Int
    let extent: Double
    let roads: [Road]
    let sourceDate: String

    func paths() -> [String: CGPath] {
        var paths: [String: CGMutablePath] = [:]
        for road in roads {
            guard road.points.count > 1 else { continue }
            let path = paths[road.kind] ?? CGMutablePath()
            for (index, point) in road.points.enumerated() where point.count == 2 {
                let p = CGPoint(x: point[0], y: -point[1])
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            paths[road.kind] = path
        }
        return paths.mapValues { $0 as CGPath }
    }
}
struct StarterMaps: Decodable {
    let cities: [StarterMap]
    static let empty = StarterMaps(cities: [])
    static let bundled: StarterMaps = {
        guard let url = Bundle(for: StarterResourceBundle.self).url(forResource: "streets", withExtension: "json", subdirectory: "StarterMaps") else { return .empty }
        return load(url: url)
    }()
    static func load(url: URL) -> StarterMaps {
        guard let data = try? Data(contentsOf: url), let maps = try? JSONDecoder().decode(Self.self, from: data) else { return .empty }
        return maps
    }
    subscript(_ city: MapCity) -> StarterMap? { cities.first { $0.name == city.name && $0.zoom == city.zoom } }
    var catalog: [MapCity] { MapCity.all.filter { self[$0] != nil } }
}
