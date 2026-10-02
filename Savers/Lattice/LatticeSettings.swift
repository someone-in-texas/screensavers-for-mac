import AppKit

enum LatticeMode:String,CaseIterable,Codable {case bloom,drift,reef,signal}
enum LatticePixel:String,CaseIterable,Codable {case fine,medium,bold}
enum LatticeGrid:String,CaseIterable,Codable {case none,subtle,crt
    var title:String {self == .crt ? "CRT":rawValue.capitalized}
}
enum LatticePalette:String,CaseIterable,Codable {
    case deepWell,amber,bioluminescent,raspberry,phosphor,ice,ember,paper
    var title:String {switch self{case .deepWell:return "Deep Well";case .amber:return "Amber Terminal";case .ice:return "Ice Cave";case .paper:return "Paper Pixel";default:return rawValue.capitalized}}
    var background:RGB {self == .paper ? RGB(0.91,0.90,0.84):self == .ember ? RGB(0.025,0.015,0.02):RGB(0.012,0.024,0.036)}
    var colors:[RGB] {
        switch self {
        case .deepWell:return [RGB(0.10,0.23,0.30),RGB(0.22,0.53,0.51),RGB(0.48,0.76,0.67),RGB(0.70,0.58,0.81)]
        case .amber:return [RGB(0.25,0.12,0.055),RGB(0.57,0.31,0.10),RGB(0.85,0.59,0.24),RGB(0.96,0.82,0.50)]
        case .bioluminescent:return [RGB(0.055,0.19,0.23),RGB(0.14,0.43,0.48),RGB(0.30,0.74,0.64),RGB(0.50,0.57,0.84)]
        case .raspberry:return [RGB(0.22,0.085,0.21),RGB(0.49,0.23,0.45),RGB(0.78,0.43,0.60),RGB(0.86,0.68,0.76)]
        case .phosphor:return [RGB(0.11,0.20,0.09),RGB(0.30,0.48,0.19),RGB(0.57,0.72,0.32),RGB(0.80,0.84,0.55)]
        case .ice:return [RGB(0.10,0.18,0.29),RGB(0.26,0.44,0.60),RGB(0.56,0.75,0.84),RGB(0.80,0.82,0.89)]
        case .ember:return [RGB(0.25,0.075,0.04),RGB(0.58,0.23,0.10),RGB(0.84,0.47,0.18),RGB(0.95,0.74,0.35)]
        case .paper:return [RGB(0.72,0.73,0.66),RGB(0.48,0.59,0.52),RGB(0.22,0.39,0.37),RGB(0.50,0.29,0.28)]
        }
    }
}
struct LatticeSettings:Codable,Equatable {
    var mode=LatticeMode.reef
    var palette=LatticePalette.deepWell
    var activity=0.45
    var speed=10.0
    var pixels=LatticePixel.medium
    var glow=0.35
    var persistence=0.55
    var events=0.45
    var grid=LatticeGrid.none
    var seedBehavior=ArtSeed.fresh
    var seed:UInt64=42
    func sanitized()->Self {var s=self;s.activity=artClamp(activity,0,1,0.45);s.speed=artClamp(speed,5,18,10);s.glow=artClamp(glow,0,1,0.35);s.persistence=artClamp(persistence,0,1,0.55);s.events=artClamp(events,0,1,0.45);return s}
}
