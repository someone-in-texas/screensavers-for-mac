import AppKit
import QuartzCore

private final class StarterResourceBundle: NSObject {}

struct StarterMap: Decodable {
    struct Road: Decodable { let kind: String; let points: [[Double]]; let name: String? }
    struct Area: Decodable { let kind: String; let rings: [[[Double]]] }
    struct Place: Decodable { let name: String; let point: [Double] }
    let name: String
    let zoom: Int
    let extent: Double
    let roads: [Road]
    let sourceDate: String
    let areas: [Area]?
    let waterways: [[[Double]]]?
    let pointsOfInterest: [Place]?

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

    /// Geometry stays vector all the way to the display. Each feature
    /// category has independent layers; toggles never erase details from a bitmap.
    func detailLayers(settings: SaverSettings, ink: NSColor) -> [CALayer] {
        var layers: [CALayer] = []
        var paths: [String: CGMutablePath] = [:]
        for area in areas ?? [] where area.kind == "water" ? settings.water : settings.parks {
            let path = paths[area.kind] ?? CGMutablePath()
            for ring in area.rings {
                for (index, point) in ring.enumerated() where point.count == 2 {
                    let p = CGPoint(x: point[0], y: -point[1])
                    if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                path.closeSubpath()
            }
            paths[area.kind] = path
        }
        for kind in paths.keys.sorted() {
            // Extractor gives holes the opposite winding, preserving islands
            // while batching thousands of polygons into two retained layers.
            let layer = CAShapeLayer(); layer.name = kind; layer.path = paths[kind]
            layer.fillColor = ink.withAlphaComponent(kind == "water" ? 0.18 : 0.09).cgColor
            layers.append(layer)
        }
        if settings.water {
            let path = CGMutablePath()
            for points in waterways ?? [] {
                for (index, point) in points.enumerated() where point.count == 2 {
                    let p = CGPoint(x: point[0], y: -point[1])
                    if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
            }
            let layer = CAShapeLayer(); layer.name = "water"; layer.path = path; layer.fillColor = nil
            layer.strokeColor = ink.withAlphaComponent(0.3).cgColor; layer.lineWidth = 2
            layers.append(layer)
        }
        return layers
    }

    func labelLayers(settings: SaverSettings, ink: NSColor, scale: CGFloat) -> [CALayer] {
        struct Label { let name: String; let point: CGPoint; let isPlace: Bool }
        var candidates: [Label] = []
        if settings.streetLabels {
            for road in roads {
                guard let name = road.name, !name.isEmpty, let p = road.points.dropFirst(road.points.count / 2).first, p.count == 2 else { continue }
                candidates.append(Label(name: name, point: CGPoint(x: p[0], y: -p[1]), isPlace: false))
            }
        }
        if settings.pointsOfInterest {
            for place in pointsOfInterest ?? [] where place.point.count == 2 {
                candidates.append(Label(name: "• " + place.name, point: CGPoint(x: place.point[0], y: -place.point[1]), isPlace: true))
            }
        }
        // Prefer central features, with deterministic collision avoidance and a
        // fixed budget. Layout happens on city/style changes, never each frame.
        candidates.sort {
            let a = hypot($0.point.x, $0.point.y), b = hypot($1.point.x, $1.point.y)
            return a == b ? $0.name < $1.name : a < b
        }
        var names = Set<String>(), occupied: [CGRect] = [], result: [CALayer] = []
        for label in candidates {
            guard result.count < 350 else { break }
            guard abs(label.point.x) < extent - 200, abs(label.point.y) < extent - 50, !names.contains(label.name) else { continue }
            let font = NSFont.systemFont(ofSize: label.isPlace ? 11 : 10, weight: label.isPlace ? .medium : .regular)
            let width = min(170, ceil((label.name as NSString).size(withAttributes: [.font: font]).width) + 4)
            let frame = CGRect(x: label.point.x - width / 2, y: label.point.y - 8, width: width, height: 16)
            let spacing = frame.insetBy(dx: -25, dy: -22)
            guard !occupied.contains(where: { $0.intersects(spacing) }) else { continue }
            names.insert(label.name); occupied.append(spacing)
            let layer = CATextLayer(); layer.name = label.isPlace ? "poi" : "street-label"
            layer.string = label.name; layer.font = font; layer.fontSize = font.pointSize
            layer.foregroundColor = ink.cgColor; layer.contentsScale = max(1, scale)
            layer.frame = frame; layer.alignmentMode = .center; layer.truncationMode = .end
            result.append(layer)
        }
        return result
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
