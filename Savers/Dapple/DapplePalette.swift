import AppKit

enum DapplePalette: String, CaseIterable, Codable {
    case meadow, seaside, dusk, paper, bauhaus, nightGarden, sorbet, autumn
    var title: String { self == .nightGarden ? "Night Garden" : rawValue.capitalized }
    var background: RGB {
        switch self {
        case .meadow: return RGB(0.94,0.92,0.85)
        case .seaside: return RGB(0.91,0.90,0.84)
        case .dusk: return RGB(0.23,0.22,0.31)
        case .paper: return RGB(0.90,0.87,0.80)
        case .bauhaus: return RGB(0.94,0.92,0.86)
        case .nightGarden: return RGB(0.075,0.13,0.17)
        case .sorbet: return RGB(0.95,0.90,0.87)
        case .autumn: return RGB(0.90,0.85,0.74)
        }
    }
    var colors: [RGB] {
        switch self {
        case .meadow: return [RGB(0.38,0.49,0.38),RGB(0.74,0.54,0.25),RGB(0.48,0.62,0.67),RGB(0.72,0.39,0.28),RGB(0.63,0.68,0.47)]
        case .seaside: return [RGB(0.30,0.49,0.57),RGB(0.80,0.46,0.35),RGB(0.52,0.67,0.61),RGB(0.20,0.31,0.39),RGB(0.78,0.66,0.45)]
        case .dusk: return [RGB(0.65,0.52,0.68),RGB(0.81,0.56,0.56),RGB(0.85,0.67,0.38),RGB(0.37,0.49,0.63),RGB(0.72,0.68,0.73)]
        case .paper: return [RGB(0.29,0.30,0.28),RGB(0.62,0.58,0.49),RGB(0.79,0.74,0.62),RGB(0.53,0.57,0.49),RGB(0.72,0.53,0.39)]
        case .bauhaus: return [RGB(0.74,0.24,0.19),RGB(0.22,0.38,0.58),RGB(0.84,0.66,0.22),RGB(0.20,0.23,0.23),RGB(0.78,0.73,0.61)]
        case .nightGarden: return [RGB(0.34,0.58,0.52),RGB(0.62,0.48,0.59),RGB(0.70,0.59,0.32),RGB(0.32,0.47,0.63),RGB(0.66,0.71,0.58)]
        case .sorbet: return [RGB(0.84,0.58,0.60),RGB(0.88,0.68,0.49),RGB(0.54,0.70,0.61),RGB(0.84,0.78,0.50),RGB(0.66,0.60,0.74)]
        case .autumn: return [RGB(0.72,0.49,0.19),RGB(0.70,0.33,0.21),RGB(0.46,0.26,0.30),RGB(0.43,0.48,0.29),RGB(0.77,0.67,0.49)]
        }
    }
}
