import AppKit
import ScreenSaver

enum SaverKind: String, CaseIterable {
    case worldClockRoom, cityDrift
    var title: String { self == .worldClockRoom ? "World Clock Room" : "City Drift" }
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

struct SaverSettings: Codable, Equatable {
    var floor = RGB(0.16, 0.20, 0.22)
    var face = RGB(0.89, 0.86, 0.76)
    var speed = 1.0
    var density = 1.0
    var smoothSeconds = true
    var labels = true
    var palette = MapPalette.paper
    var intensity = 0.85
    var grain = false
    var vignette = true
    func sanitized() -> Self {
        var copy = self
        if !copy.floor.valid { copy.floor = Self().floor }
        if !copy.face.valid { copy.face = Self().face }
        copy.speed = speed.isFinite ? min(2, max(0, speed)) : 1
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
            guard let data = defaults.data(forKey: "settings.v1"),
                  let value = try? JSONDecoder().decode(SaverSettings.self, from: data) else { return .init() }
            return value.sanitized()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue.sanitized()) {
                defaults.set(data, forKey: "settings.v1")
                defaults.synchronize()
            }
        }
    }
    func reset() { defaults.removeObject(forKey: "settings.v1"); defaults.synchronize() }
}
