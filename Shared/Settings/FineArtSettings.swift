import Foundation

protocol FineChoice: RawRepresentable, CaseIterable, Codable, Equatable where RawValue == String {}
extension FineChoice { var title: String { rawValue } }
enum ResearchGround: String, FineChoice {
    case ivory = "Blue Chair / Ivory", charcoal = "Blue Chair / Charcoal", blueprint = "Blueprint", white = "Gallery White", nocturne = "Nocturne"
    var colors: PrintColors {
        switch self {
        case .ivory: return PrintColors(RGB(0.935,0.917,0.870), RGB(0.28,0.28,0.26), RGB(0.24,0.36,0.55))
        case .charcoal: return PrintColors(RGB(0.105,0.115,0.12), RGB(0.65,0.65,0.60), RGB(0.34,0.49,0.61))
        case .blueprint: return PrintColors(RGB(0.13,0.20,0.26), RGB(0.67,0.73,0.73), RGB(0.43,0.57,0.64))
        case .white: return PrintColors(RGB(0.945,0.945,0.928), RGB(0.24,0.27,0.29), RGB(0.29,0.44,0.56))
        case .nocturne: return PrintColors(RGB(0.06,0.085,0.115), RGB(0.45,0.51,0.55), RGB(0.28,0.40,0.52))
        }
    }
}
enum ResearchDrawing: String, FineChoice { case orthographic = "Orthographic", labyrinth = "Labyrinth", blueprint = "Blueprint", recursive = "Recursive", sparse = "Sparse" }
enum PrintLine: String, FineChoice { case technical = "Technical Pen", ink = "Drafting Ink", graphite = "Graphite", etched = "Etched" }
enum ChairMotion: String, FineChoice {
    case still = "Still", occasional = "Occasional Turn", rotation = "Slow Rotation"
    func angle(_ time: Double) -> Double {
        let t = max(0,time.isFinite ? time : 0).truncatingRemainder(dividingBy: 1200)
        switch self {
        case .still: return -0.24
        case .rotation: return -0.24 + sin(t * .pi * 2 / 300) * 0.42
        case .occasional:
            let phase = t / 80, step = floor(phase)
            return -0.24 + 0.24 * (sin(step * .pi * 2 / 15) + (sin((step+1) * .pi * 2 / 15)-sin(step * .pi * 2 / 15))*worldEase((phase-step-0.72)/0.28))
        }
    }
}
enum PrintPace: String, FineChoice { case meditative = "Meditative", measured = "Measured", attentive = "Attentive"; var rate:Double {self == .meditative ? 0.65 : self == .measured ? 1 : 1.4} }
enum PrintDensity: String, FineChoice { case open = "Open", balanced = "Balanced", dense = "Dense"; var count:Int {self == .open ? 10 : self == .balanced ? 16 : 23} }
enum ResearchComposition: String, FineChoice { case centered = "Centered", asymmetric = "Asymmetric", radial = "Radial", gallery = "Gallery" }
struct ResearchFineSettings: Codable, Equatable {
    var palette = ResearchGround.ivory
    var drawing = ResearchDrawing.labyrinth
    var line = PrintLine.graphite
    var chair = ChairMotion.occasional
    var pace = PrintPace.measured
    var density = PrintDensity.balanced
    var composition = ResearchComposition.asymmetric
}
enum StrawberryGround: String, FineChoice {
    case ivory = "Ivory & Crimson", charcoal = "Charcoal & Garnet", sage = "Sage & Carmine", night = "Museum Night", monograph = "Paper Monograph", vellum = "Pale Vellum"
    var colors: PrintColors {
        switch self {
        case .ivory: return PrintColors(RGB(0.94,0.92,0.87), RGB(0.40,0.30,0.22), RGB(0.53,0.12,0.17))
        case .charcoal: return PrintColors(RGB(0.115,0.12,0.12), RGB(0.59,0.43,0.30), RGB(0.49,0.18,0.22))
        case .sage: return PrintColors(RGB(0.79,0.82,0.76), RGB(0.34,0.36,0.28), RGB(0.55,0.19,0.22))
        case .night: return PrintColors(RGB(0.065,0.085,0.11), RGB(0.50,0.40,0.32), RGB(0.46,0.16,0.21))
        case .monograph: return PrintColors(RGB(0.91,0.90,0.86), RGB(0.36,0.34,0.31), RGB(0.42,0.23,0.24))
        case .vellum: return PrintColors(RGB(0.89,0.85,0.76), RGB(0.39,0.33,0.27), RGB(0.52,0.25,0.25))
        }
    }
}
struct PrintColors { let ground:RGB, ink:RGB, pigment:RGB; init(_ ground:RGB,_ ink:RGB,_ pigment:RGB){self.ground=ground;self.ink=ink;self.pigment=pigment} }
enum StrawberryComposition: String, FineChoice { case suspended = "Suspended", anchored = "Anchored", triptych = "Triptych", asymmetric = "Asymmetric", clustered = "Clustered" }
enum RootBlend: String, FineChoice { case organic = "Organic", balanced = "Balanced", threshold = "Threshold", synthetic = "Synthetic"; var threshold:Double {self == .organic ? 0.84 : self == .balanced ? 0.57 : self == .threshold ? 0.69 : 0.33} }
enum PrintMotion: String, FineChoice { case still = "Still", pulse = "Slow Pulse", growth = "Growth", breathing = "Breathing" }
enum PrintTexture: String, FineChoice { case smooth = "Smooth", paper = "Paper", vellum = "Vellum", canvas = "Canvas" }
enum FormLiteralness: String, FineChoice { case abstract = "Abstract", suggestive = "Suggestive", botanical = "Botanical" }
enum PrintSignal: String, FineChoice { case hidden = "Hidden", subtle = "Subtle", present = "Present" }
struct StrawberryFineSettings: Codable, Equatable {
    var palette = StrawberryGround.ivory
    var composition = StrawberryComposition.suspended
    var blend = RootBlend.balanced
    var motion = PrintMotion.growth
    var texture = PrintTexture.paper
    var literalness = FormLiteralness.suggestive
    var signal = PrintSignal.subtle
}
