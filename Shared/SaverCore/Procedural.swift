import Foundation

/// Shared deterministic randomness for procedural scenes. Rendering never consumes it.
struct ArtRandom {
    var state: UInt64
    mutating func next() -> Double {
        state &+= 0x9e3779b97f4a7c15
        var z = state; z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return Double((z ^ (z >> 31)) >> 11) / 9007199254740992
    }
}
enum ArtSeed: String, CaseIterable, Codable {
    case fresh, daily, fixed
    var title: String { switch self { case .fresh: return "New each session"; case .daily: return "Daily composition"; case .fixed: return "Fixed seed" } }
    func resolve(fresh: UInt64, fixed: UInt64, date: Date) -> UInt64 {
        switch self { case .fresh: return fresh; case .fixed: return fixed; case .daily: return UInt64(max(0,floor(date.timeIntervalSince1970/86400))) &* 0x9e3779b97f4a7c15 }
    }
}
func artClamp(_ value: Double, _ lower: Double, _ upper: Double, _ fallback: Double) -> Double { value.isFinite ? min(upper,max(lower,value)) : fallback }
