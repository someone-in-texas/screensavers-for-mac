import AppKit

enum FlourishStyle: String, CaseIterable, Codable { case natural, ornamental, spiral, wild, sparse }
enum FlourishBackground: String, CaseIterable, Codable { case paper, clean, vellum }
enum FlourishLine: String, CaseIterable, Codable { case finePen, brushPen, etching
    var title: String { switch self { case .finePen: return "Fine Pen"; case .brushPen: return "Brush Pen"; case .etching: return "Etching" } }
}
enum FlourishPalette: String, CaseIterable, Codable {
    case botanical, midnight, copperplate, wildflower, porcelain, herbarium, autumn, frost
    var title: String { switch self { case .botanical:return "Botanical Ink";case .midnight:return "Midnight Garden";case .herbarium:return "Neon Herbarium";default:return rawValue.capitalized } }
    var background: RGB {
        switch self {
        case .midnight:return RGB(0.035,0.065,0.10)
        case .herbarium:return RGB(0.035,0.035,0.065)
        case .porcelain:return RGB(0.92,0.95,0.95)
        case .frost:return RGB(0.18,0.24,0.29)
        default:return RGB(0.96,0.94,0.88)
        }
    }
    var inks: [RGB] {
        switch self {
        case .botanical:return [RGB(0.20,0.32,0.24),RGB(0.38,0.45,0.26),RGB(0.27,0.40,0.43),RGB(0.64,0.42,0.17)]
        case .midnight:return [RGB(0.40,0.73,0.66),RGB(0.62,0.75,0.59),RGB(0.66,0.57,0.77),RGB(0.79,0.65,0.37)]
        case .copperplate:return [RGB(0.38,0.25,0.18),RGB(0.52,0.35,0.22),RGB(0.42,0.48,0.35),RGB(0.70,0.39,0.25)]
        case .wildflower:return [RGB(0.29,0.42,0.30),RGB(0.45,0.48,0.29),RGB(0.41,0.43,0.60),RGB(0.73,0.35,0.31)]
        case .porcelain:return [RGB(0.18,0.33,0.55),RGB(0.30,0.48,0.58),RGB(0.33,0.47,0.47),RGB(0.36,0.39,0.61)]
        case .herbarium:return [RGB(0.38,0.70,0.71),RGB(0.54,0.71,0.45),RGB(0.62,0.49,0.75),RGB(0.79,0.46,0.63)]
        case .autumn:return [RGB(0.40,0.40,0.22),RGB(0.54,0.26,0.26),RGB(0.60,0.38,0.17),RGB(0.72,0.37,0.21)]
        case .frost:return [RGB(0.72,0.82,0.85),RGB(0.56,0.72,0.79),RGB(0.68,0.66,0.78),RGB(0.86,0.87,0.84)]
        }
    }
}
struct FlourishSettings: Codable, Equatable {
    var style = FlourishStyle.natural
    var palette = FlourishPalette.botanical
    var speed = 1.0
    var density = 0.55
    var flowers = 0.45
    var leaves = 0.65
    var background = FlourishBackground.paper
    var line = FlourishLine.finePen
    var wash = true
    var breeze = false
    var seedBehavior = ArtSeed.fresh
    var seed: UInt64 = 42
    func sanitized() -> Self {
        var s=self; s.speed=artClamp(speed,0.3,2,1);s.density=artClamp(density,0,1,0.55)
        s.flowers=artClamp(flowers,0,1,0.45);s.leaves=artClamp(leaves,0,1,0.65);return s
    }
}
