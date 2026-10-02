import Foundation

enum PaperCamera: String, CaseIterable, Codable {
    case journey, isometric, chase, side
    var title: String {
        switch self {
        case .journey: return "Changing viewpoints"
        case .isometric: return "Isometric glide"
        case .chase: return "Follow the plane · 3D"
        case .side: return "Side-on flight · 2D"
        }
    }
}
enum PaperPalette: String, CaseIterable, Codable {
    case evolving, afterglow, coral, violet, lagoon
    var title: String { self == .evolving ? "Evolving sunsets" : rawValue.capitalized }
}
struct PaperSkySettings: Codable, Equatable {
    var camera = PaperCamera.journey
    var palette = PaperPalette.evolving
    var secondsPerView = 45.0
    var speed = 1.0
    var clouds = 0.7
    var companions = true
    var trails = true
    var sun = true
    var glow = 0.35
    func sanitized() -> Self {
        var s = self
        func clamp(_ v: Double, _ lo: Double, _ hi: Double, _ fallback: Double) -> Double { v.isFinite ? min(hi, max(lo, v)) : fallback }
        s.secondsPerView = clamp(s.secondsPerView, 20, 120, 45)
        s.speed = clamp(s.speed, 0, 3, 1)
        s.clouds = clamp(s.clouds, 0, 1, 0.7)
        s.glow = clamp(s.glow, 0, 1, 0.35)
        return s
    }
}
