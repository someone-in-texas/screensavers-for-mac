import Foundation

enum CosmosView: String, CaseIterable, Codable {
    case tour, solarSystem, innerPlanets, outerPlanets, mercury, venus, earth, mars, jupiter, saturn, uranus, neptune, asteroidBelt, deepSpace
    var title: String {
        switch self {
        case .tour: return "Grand tour"
        case .solarSystem: return "Solar system"
        case .innerPlanets: return "Inner planets"
        case .outerPlanets: return "Outer planets"
        case .asteroidBelt: return "Asteroid belt"
        case .deepSpace: return "Deep space"
        default: return rawValue.capitalized
        }
    }
    var planet: Int? { [.mercury, .venus, .earth, .mars, .jupiter, .saturn, .uranus, .neptune].firstIndex(of: self) }
    // Alternate wide compositions and intimate portraits; every planet gets a visit.
    static let itinerary: [Self] = [.solarSystem, .earth, .saturn, .innerPlanets, .mars, .venus, .asteroidBelt, .jupiter, .outerPlanets, .neptune, .uranus, .mercury, .deepSpace]
}
enum CosmosBackground: String, CaseIterable, Codable {
    case nebula, aurora, stars, void
    var title: String { self == .void ? "Black void" : rawValue.capitalized }
}
enum CosmosAngle: String, CaseIterable, Codable {
    case roaming, classic, low, high
    var title: String {
        switch self { case .roaming: return "Changing angles"; case .classic: return "Classic isometric"; case .low: return "Low horizon"; case .high: return "Overhead oblique" }
    }
}
struct CosmosSettings: Codable, Equatable {
    var view = CosmosView.tour
    var background = CosmosBackground.nebula
    var angle = CosmosAngle.roaming
    var secondsPerView = 40.0
    var speed = 1.0
    var pixelSize = 3.0
    var glow = 0.35
    var starDensity = 0.7
    var orbits = true
    var labels = true
    var asteroids = true
    func sanitized() -> Self {
        var s = self
        func clamp(_ v: Double, _ low: Double, _ high: Double, _ fallback: Double) -> Double { v.isFinite ? min(high, max(low, v)) : fallback }
        s.secondsPerView = clamp(s.secondsPerView, 15, 120, 40)
        s.speed = clamp(s.speed, 0, 3, 1)
        s.pixelSize = clamp(s.pixelSize.rounded(), 2, 5, 3)
        s.glow = clamp(s.glow, 0, 1, 0.35)
        s.starDensity = clamp(s.starDensity, 0, 1, 0.7)
        return s
    }
}
