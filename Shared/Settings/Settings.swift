import AppKit
import ScreenSaver

enum SaverKind: String, CaseIterable {
    case worldClockRoom, cityDrift, voxelCosmos
    var title: String {
        switch self { case .worldClockRoom: return "World Clock Room"; case .cityDrift: return "City Drift"; case .voxelCosmos: return "Voxel Cosmos" }
    }
    var identifier: String { "com.someoneintexas.screensavers.\(rawValue.lowercased())" }
}

struct RGB: Codable, Equatable {
    var r: Double; var g: Double; var b: Double
    var color: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    init(_ color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? .gray
        self.init(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
    }
    var valid: Bool { [r,g,b].allSatisfy { $0.isFinite && (0...1).contains($0) } }
}

enum MapPalette: String, CaseIterable, Codable { case original, ink, blueprint, night, paper, terminal }
enum MapStyle: String, CaseIterable, Codable { case online, lines, traditional }

struct SaverSettings: Codable, Equatable {
    var cosmos = CosmosSettings()
    var floor = RGB(0.16, 0.20, 0.22)
    var face = RGB(0.89, 0.86, 0.76)
    static let maximumSpeed = 16.0
    var speed = 6.0
    var density = 1.0
    var smoothSeconds = true
    var labels = true
    var palette = MapPalette.paper
    var intensity = 0.85
    var grain = false
    var vignette = false
    let mapSourceVersion = 1
    var mapStyle = MapStyle.online
    var streetLabels = false
    var water = false
    var parks = false
    var pointsOfInterest = false
    init() {}
    private enum CodingKeys: String, CodingKey {
        case cosmos
        case floor, face, speed, density, smoothSeconds, labels, palette, intensity, grain, vignette
        case mapSourceVersion, mapStyle, streetLabels, water, parks, pointsOfInterest
    }
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cosmos = try c.decodeIfPresent(CosmosSettings.self, forKey: .cosmos) ?? cosmos
        floor = try c.decodeIfPresent(RGB.self, forKey: .floor) ?? floor
        face = try c.decodeIfPresent(RGB.self, forKey: .face) ?? face
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? speed
        density = try c.decodeIfPresent(Double.self, forKey: .density) ?? density
        smoothSeconds = try c.decodeIfPresent(Bool.self, forKey: .smoothSeconds) ?? smoothSeconds
        labels = try c.decodeIfPresent(Bool.self, forKey: .labels) ?? labels
        palette = try c.decodeIfPresent(MapPalette.self, forKey: .palette) ?? palette
        intensity = try c.decodeIfPresent(Double.self, forKey: .intensity) ?? intensity
        grain = try c.decodeIfPresent(Bool.self, forKey: .grain) ?? grain
        vignette = try c.decodeIfPresent(Bool.self, forKey: .vignette) ?? vignette
        mapStyle = try c.decodeIfPresent(MapStyle.self, forKey: .mapStyle) ?? mapStyle
        if try c.decodeIfPresent(Int.self, forKey: .mapSourceVersion) == nil, mapStyle == .lines { mapStyle = .online }
        streetLabels = try c.decodeIfPresent(Bool.self, forKey: .streetLabels) ?? streetLabels
        water = try c.decodeIfPresent(Bool.self, forKey: .water) ?? water
        parks = try c.decodeIfPresent(Bool.self, forKey: .parks) ?? parks
        pointsOfInterest = try c.decodeIfPresent(Bool.self, forKey: .pointsOfInterest) ?? pointsOfInterest
    }
    func sanitized() -> Self {
        var copy = self
        copy.cosmos = cosmos.sanitized()
        if !copy.floor.valid { copy.floor = Self().floor }
        if !copy.face.valid { copy.face = Self().face }
        copy.speed = speed.isFinite ? min(Self.maximumSpeed, max(0, speed)) : Self().speed
        copy.density = density.isFinite ? min(1.4, max(0.7, density)) : 1
        copy.intensity = intensity.isFinite ? min(1, max(0, intensity)) : 0.85
        return copy
    }
}

final class SettingsStore {
    let defaults: UserDefaults
    let kind: SaverKind
    init(_ kind: SaverKind, defaults: UserDefaults? = nil) {
        self.kind = kind
        self.defaults = defaults ?? ScreenSaverDefaults(forModuleWithName: kind.identifier) ?? UserDefaults(suiteName: kind.identifier)!
    }
    var value: SaverSettings {
        get {
            if let data = defaults.data(forKey: "settings.v2"),
               let value = try? JSONDecoder().decode(SaverSettings.self, from: data) { return value.sanitized() }
            guard let data = defaults.data(forKey: "settings.v1"),
                  var value = try? JSONDecoder().decode(SaverSettings.self, from: data) else { return .init() }
            // Preserve a paused camera and the relative preference while upgrading the old range.
            value.speed = value.speed.isFinite ? min(2, max(0, value.speed)) * 6 : SaverSettings().speed
            let migrated = value.sanitized()
            if let encoded = try? JSONEncoder().encode(migrated) { defaults.set(encoded, forKey: "settings.v2") }
            return migrated
        }
        set {
            if let data = try? JSONEncoder().encode(newValue.sanitized()) {
                defaults.set(data, forKey: "settings.v2")
                defaults.synchronize()
            }
        }
    }
    func reset() {
        defaults.removeObject(forKey: "settings.v1"); defaults.removeObject(forKey: "settings.v2")
        defaults.synchronize()
    }
}
