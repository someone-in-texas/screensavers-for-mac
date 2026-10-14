import Foundation

enum BloomPlant: String, CaseIterable, Codable {
    case automatic, oak, maple, birch, willow, pine, spruce, cedar, dogwood, japaneseMaple
    case sunflower, lavender, coneflower, grass, fern, rose, wildflowers, sage, fruitTree
    var title: String {
        switch self { case .automatic: return "Automatic / mixed"; case .japaneseMaple: return "Japanese maple"
        case .fruitTree: return "Fruit tree"; case .grass: return "Wild grass"; default: return rawValue.capitalized }
    }
    var evergreen: Bool { [.pine, .spruce, .cedar].contains(self) }
    var woody: Bool { [.oak, .maple, .birch, .willow, .pine, .spruce, .cedar, .dogwood, .japaneseMaple, .rose, .sage, .fruitTree].contains(self) }
    var annual: Bool { [.sunflower, .wildflowers].contains(self) }
    var narrow: Bool { [.birch, .pine, .spruce, .cedar].contains(self) }
}
enum BloomLayout: String, CaseIterable, Codable { case automatic, specimen, grouping, meadow, woodland }
enum BloomPalette: String, CaseIterable, Codable { case botanical, vintage, moonlit, golden, pastel, ink, vesper }
enum BloomPace: String, CaseIterable, Codable { case relaxed, normal, fast
    var secondsPerYear: Double { self == .relaxed ? 100 : self == .normal ? 65 : 40 }
}
enum BloomWeather: String, CaseIterable, Codable { case calm, natural, dramatic }
enum BloomTexture: String, CaseIterable, Codable { case subtle, medium, strong }
enum BloomSeason: String, CaseIterable, Codable { case balanced, spring, summer, autumn, winter }
enum BloomRendering: String, CaseIterable, Codable {
    case classic, organic, botanicalWatercolor
    var title: String { self == .botanicalWatercolor ? "Botanical Watercolor" : rawValue.capitalized }
}

/// Artistic intensities, mapped to small geometry offsets and optical densities
/// by BloomIllustration. Optional storage keeps every pre-existing setting intact.
struct BloomArtSettings: Codable, Equatable {
    var rendering = BloomRendering.botanicalWatercolor
    var edgeIrregularity = 0.35
    var pigmentVariation = 0.65
    var paperGrain = 0.30
    var wetEdges = 0.25
    init() {}
    private enum CodingKeys: String, CodingKey { case rendering, edgeIrregularity, pigmentVariation, paperGrain, wetEdges }
    init(from decoder: Decoder) throws {
        self.init()
        guard let c = try? decoder.container(keyedBy:CodingKeys.self) else { return }
        rendering = (try? c.decode(BloomRendering.self,forKey:.rendering)) ?? rendering
        edgeIrregularity = (try? c.decode(Double.self,forKey:.edgeIrregularity)) ?? edgeIrregularity
        pigmentVariation = (try? c.decode(Double.self,forKey:.pigmentVariation)) ?? pigmentVariation
        paperGrain = (try? c.decode(Double.self,forKey:.paperGrain)) ?? paperGrain
        wetEdges = (try? c.decode(Double.self,forKey:.wetEdges)) ?? wetEdges
        self = sanitized()
    }
    func sanitized() -> Self {
        var result = self
        func unit(_ value: Double, _ fallback: Double) -> Double { value.isFinite ? min(1,max(0,value)) : fallback }
        result.edgeIrregularity = unit(edgeIrregularity,0.35)
        result.pigmentVariation = unit(pigmentVariation,0.65)
        result.paperGrain = unit(paperGrain,0.30)
        result.wetEdges = unit(wetEdges,0.25)
        return result
    }
}
struct BloomSettings: Codable, Equatable {
    var plant = BloomPlant.automatic
    var layout = BloomLayout.automatic
    var palette = BloomPalette.botanical
    var pace = BloomPace.normal
    var weather = BloomWeather.natural
    var texture = BloomTexture.medium
    var emphasis = BloomSeason.balanced
    var seed: UInt64 = 42
    var illustration: BloomArtSettings? = nil
    var art: BloomArtSettings {
        get { (illustration ?? BloomArtSettings()).sanitized() }
        set { illustration = newValue.sanitized() }
    }
}

/// Calendar and plant geometry are independent of the renderer. Five-year cohorts
/// overlap at renewal; seasonal emphasis lengthens a season without freezing time.
struct BloomCalendar {
    let year: Int
    let phase: Double
    let foliage: Double
    let bloom: Double
    let autumn: Double
    let winter: Double
    let rain: Double
    let wind: Double
    init(years: Double, settings: BloomSettings) {
        let safe = max(0, years.isFinite ? years : 0)
        year = Int(min(safe, 1_000_000))
        let raw = safe - floor(safe)
        let index = BloomSeason.allCases.firstIndex(of: settings.emphasis) ?? 0
        let weights = (0..<4).map { $0 == index-1 ? 1.65 : 1.0 }
        let target = raw * weights.reduce(0, +)
        var traversed = 0.0, adjusted = 0.0
        for i in 0..<4 {
            if target >= traversed && target < traversed + weights[i] { adjusted = (Double(i) + (target-traversed)/weights[i])/4 }
            traversed += weights[i]
        }
        phase = adjusted
        func ramp(_ a: Double, _ b: Double, _ x: Double) -> Double { let p = min(1,max(0,(x-a)/(b-a))); return p*p*(3-2*p) }
        foliage = ramp(0.02,0.23,phase) * (1-ramp(0.57,0.80,phase))
        bloom = ramp(0.16,0.32,phase) * (1-ramp(0.47,0.63,phase))
        autumn = ramp(0.48,0.72,phase)
        winter = ramp(0.73,0.9,phase) * (1-ramp(0.94,1,phase))
        let weatherScale = settings.weather == .calm ? 0.16 : settings.weather == .dramatic ? 1.0 : 0.58
        let storm = max(0, sin(safe*19.7+0.4)*0.7 + sin(safe*7.31)*0.3)
        rain = weatherScale * storm * (1-winter)
        wind = weatherScale * (0.2 + storm*0.8)
    }
}
