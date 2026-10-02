import Foundation

enum DappleMotion: String, CaseIterable, Codable { case hills, float, playground, zen }
enum DappleMaterial: String, CaseIterable, Codable { case paper, ink, ceramic, soft }
enum DappleDensity: String, CaseIterable, Codable { case sparse, balanced, full }
enum DappleSize: String, CaseIterable, Codable { case small, mixed, large }
enum DappleSeed: String, CaseIterable, Codable {
    case fresh, daily, fixed
    var title: String { switch self { case .fresh: return "New scene each launch"; case .daily: return "Same daily scene"; case .fixed: return "Fixed seed" } }
}
struct DappleSettings: Codable, Equatable {
    var palette = DapplePalette.meadow
    var material = DappleMaterial.paper
    var motion = DappleMotion.hills
    var density = DappleDensity.balanced
    var size = DappleSize.mixed
    var speed = 1.0
    var texture = 0.55
    var shadows = true
    var backgroundTexture = true
    var events = true
    var seedBehavior = DappleSeed.fresh
    var seed: UInt64 = 42
    func sanitized() -> Self {
        var s = self
        s.speed = speed.isFinite ? min(1.7, max(0.35, speed)) : 1
        s.texture = texture.isFinite ? min(1, max(0, texture)) : 0.55
        return s
    }
    func resolvedSeed(fresh: UInt64, date: Date) -> UInt64 {
        switch seedBehavior {
        case .fresh: return fresh
        case .fixed: return seed
        case .daily: return UInt64(max(0, floor(date.timeIntervalSince1970 / 86400))) &* 0x9e3779b97f4a7c15
        }
    }
}
/// SplitMix64: randomness is consumed only during generation, never while drawing.
struct DappleRandom {
    var state: UInt64
    mutating func next() -> Double {
        state &+= 0x9e3779b97f4a7c15
        var z = state; z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return Double((z ^ (z >> 31)) >> 11) / 9007199254740992
    }
}
