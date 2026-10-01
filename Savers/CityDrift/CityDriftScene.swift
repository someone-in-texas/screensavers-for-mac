import AppKit
import CoreImage
import QuartzCore

final class CityDriftScene: SaverScene {
    private var settings = SaverSettings()
    private let store: SettingsStore
    private let networkEnabled: Bool
    private(set) var city: MapCity
    private var loader: TileLoader?
    private var tiles: [TileID: CGImage] = [:]
    private var placements: [TilePlacement] = []
    private var dirty = true
    private var atlas: CGImage?
    private var previousAtlas: CGImage?
    private var fadeStart = 0.0
    private var motion = MotionClock()
    private var running = false
    private var generation = 0
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private let atlasSize = CGSize(width: 2560, height: 1792)
    private var origin = CGPoint.zero
    private var baseCenter = CGPoint.zero
    private let mapLayer = CALayer()
    private let oldMapLayer = CALayer()
    private let overlayLayer = CALayer()
    private var overlaySize = CGSize.zero
    private var overlayDirty = true
    private var atlasRevision = 0
    private var layerRevision = -1
    private let provider: TileProvider
    init(store: SettingsStore, networkEnabled: Bool = true, city: MapCity? = nil, provider: TileProvider = .osm) {
        self.store = store; self.networkEnabled = networkEnabled; self.provider = provider
        self.city = city ?? MapCity.choose(recent: store.defaults.stringArray(forKey: "recentCities") ?? [])
        setOrigin()
    }
    private func setOrigin() {
        baseCenter = Mercator.point(latitude: city.latitude, longitude: city.longitude, zoom: city.zoom)
        origin = CGPoint(x: floor(baseCenter.x / 256) * 256 - 1280, y: floor(baseCenter.y / 256) * 256 - 768)
    }
    func start() {
        guard !running else { return }
        running = true; motion.pause(); generation += 1
        var recent = store.defaults.stringArray(forKey: "recentCities") ?? []
        recent.append(city.name); store.defaults.set(Array(recent.suffix(8)), forKey: "recentCities")
        let session = generation
        if networkEnabled {
            loader = TileLoader(provider: provider) { [weak self] id, image in
                guard let self, self.running, self.generation == session else { return }
                self.tiles[id] = image; self.dirty = true
            }
        }
        placements = []
    }
    func stop() { running = false; generation += 1; loader?.stop(); loader = nil; motion.pause() }
    func apply(_ settings: SaverSettings) {
        if self.settings.palette != settings.palette || self.settings.intensity != settings.intensity || self.settings.grain != settings.grain { dirty = true }
        overlayDirty = overlayDirty || self.settings != settings
        self.settings = settings
    }
    /// Deterministic synthetic cartography for automated smoke tests; never contacts OSM.
    func useFixture(_ image: CGImage) {
        for tile in Mercator.viewport(center: baseCenter, size: CGSize(width: 2048, height: 1280), zoom: city.zoom) { tiles[tile.id] = image }
        dirty = true
    }
    private var background: NSColor {
        switch settings.palette {
        case .blueprint: return NSColor(srgbRed: 0.065, green: 0.16, blue: 0.25, alpha: 1)
        case .night: return NSColor(srgbRed: 0.07, green: 0.085, blue: 0.105, alpha: 1)
        case .terminal: return NSColor(srgbRed: 0.06, green: 0.12, blue: 0.10, alpha: 1)
        case .paper: return NSColor(srgbRed: 0.88, green: 0.84, blue: 0.74, alpha: 1)
        default: return NSColor(srgbRed: 0.91, green: 0.92, blue: 0.89, alpha: 1)
        }
    }
    private var ink: NSColor {
        switch settings.palette {
        case .blueprint: return NSColor(srgbRed: 0.68, green: 0.85, blue: 0.89, alpha: 1)
        case .night: return NSColor(srgbRed: 0.69, green: 0.74, blue: 0.77, alpha: 1)
        case .terminal: return NSColor(srgbRed: 0.53, green: 0.72, blue: 0.57, alpha: 1)
        case .paper: return NSColor(srgbRed: 0.23, green: 0.22, blue: 0.18, alpha: 1)
        default: return NSColor(srgbRed: 0.16, green: 0.19, blue: 0.20, alpha: 1)
        }
    }
    private func rebuild(time: Double) {
        guard let c = bitmap(width: Int(atlasSize.width), height: Int(atlasSize.height)) else { return }
        c.setFillColor(background.cgColor); c.fill(CGRect(origin: .zero, size: atlasSize))
        // Compose first, then grade once per tile batch / settings change, never per frame.
        guard let raw = bitmap(width: Int(atlasSize.width), height: Int(atlasSize.height)) else { return }
        for y in 0..<7 {
            for x in 0..<10 {
                let tx = Int(origin.x / 256) + x, ty = Int(origin.y / 256) + y
                if let id = TileID(z: city.zoom, x: tx, y: ty), let image = tiles[id] {
                    raw.draw(image, in: CGRect(x: x * 256, y: (6 - y) * 256, width: 256, height: 256))
                }
            }
        }
        if let image = raw.makeImage() {
            let input = CIImage(cgImage: image)
            var output = input
            if settings.palette != .original {
                let dark = [.blueprint, .night, .terminal].contains(settings.palette)
                if dark {
                    output = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                        .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 1.7])
                        .applyingFilter("CIFalseColor", parameters: ["inputColor0": CIColor(color: background)!, "inputColor1": CIColor(color: ink)!])
                } else {
                    output = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.18])
                        .applyingFilter("CIFalseColor", parameters: ["inputColor0": CIColor(color: ink)!, "inputColor1": CIColor(color: background)!])
                }
            }
            if let graded = imageContext.createCGImage(output, from: input.extent) {
                c.draw(image, in: CGRect(origin: .zero, size: atlasSize))
                c.setAlpha(settings.palette == .original ? 1 : settings.intensity)
                c.draw(graded, in: CGRect(origin: .zero, size: atlasSize)); c.setAlpha(1)
            }
        }
        if settings.grain {
            // Static texture; no random shimmer and no per-frame noise generation.
            var seed: UInt64 = 47
            for _ in 0..<18000 {
                seed = seed &* 6364136223846793005 &+ 1
                let x = Int((seed >> 32) % 2560)
                seed = seed &* 6364136223846793005 &+ 1
                let y = Int((seed >> 32) % 1792)
                c.setFillColor(ink.withAlphaComponent(0.035).cgColor)
                c.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        previousAtlas = atlas; atlas = c.makeImage(); fadeStart = time; dirty = false; atlasRevision += 1
    }
    private func prepare(size: CGSize, time: Double) -> (CGRect, CGSize, Double) {
        motion.step(now: time, speed: settings.speed)
        let drift = Mercator.drift(motion.elapsed)
        let center = CGPoint(x: baseCenter.x + drift.x, y: baseCenter.y + drift.y)
        let viewport = Mercator.renderSize(size)
        let visible = Mercator.viewport(center: center, size: viewport, zoom: city.zoom)
        if visible != placements {
            placements = visible
            if running { loader?.request(visible.map(\.id)) }
        }
        if dirty && (atlas == nil || time - fadeStart > 0.25) { rebuild(time: time) }
        let rect = CGRect(x: viewport.width / 2 - (center.x - origin.x),
                          y: viewport.height / 2 - (atlasSize.height - (center.y - origin.y)),
                          width: atlasSize.width, height: atlasSize.height)
        return (rect, viewport, min(1, max(0, (time - fadeStart) / 1.2)))
    }
    func updateLayer(_ root: CALayer, size: CGSize, time: Double, date: Date) -> Bool {
        let (rect, viewport, fade) = prepare(size: size, time: time)
        if mapLayer.superlayer !== root {
            root.masksToBounds = true
            root.addSublayer(oldMapLayer); root.addSublayer(mapLayer); root.addSublayer(overlayLayer)
        }
        root.backgroundColor = background.cgColor
        let scaled = CGRect(x: rect.minX * size.width / viewport.width, y: rect.minY * size.height / viewport.height,
                            width: rect.width * size.width / viewport.width, height: rect.height * size.height / viewport.height)
        mapLayer.frame = scaled; oldMapLayer.frame = scaled
        if layerRevision != atlasRevision {
            oldMapLayer.contents = previousAtlas; mapLayer.contents = atlas; layerRevision = atlasRevision
        }
        mapLayer.opacity = Float(fade)
        if fade >= 1 { previousAtlas = nil; oldMapLayer.contents = nil }
        if overlaySize != size || overlayDirty {
            let pixels = Mercator.renderSize(size)
            if let c = bitmap(width: Int(ceil(pixels.width)), height: Int(ceil(pixels.height))) {
                drawOverlays(in: c, size: pixels)
                overlayLayer.contents = c.makeImage()
            }
            overlayLayer.frame = CGRect(origin: .zero, size: size)
            overlaySize = size; overlayDirty = false
        }
        return true
    }
    func draw(in c: CGContext, size: CGSize, time: Double, date: Date) {
        let (rect, viewport, fade) = prepare(size: size, time: time)
        c.setFillColor(background.cgColor); c.fill(CGRect(origin: .zero, size: size))
        c.saveGState(); c.scaleBy(x: size.width / viewport.width, y: size.height / viewport.height)
        if let previousAtlas { c.draw(previousAtlas, in: rect) }
        if let atlas { c.setAlpha(fade); c.draw(atlas, in: rect); c.setAlpha(1) }
        if fade >= 1 { previousAtlas = nil }
        c.restoreGState()
        drawOverlays(in: c, size: size)
    }
    private func drawOverlays(in c: CGContext, size: CGSize) {
        if settings.vignette, let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [NSColor.clear.cgColor, NSColor.black.withAlphaComponent(0.17 * settings.intensity).cgColor] as CFArray, locations: [0, 1]) {
            c.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: size.height * 0.22,
                                 endCenter: CGPoint(x: size.width / 2, y: size.height / 2), endRadius: max(size.width, size.height) * 0.65, options: [.drawsAfterEndLocation])
        }
        withAppKit(c) {
            let margin: CGFloat = size.width < 500 ? 12 : 36
            let compact = size.width < 600
            // Opaque quiet plaques preserve contrast through every palette and loading state.
            if settings.labels && size.height > 110 {
                let name = city.name.uppercased()
                let fontSize: CGFloat = compact ? 13 : 23
                let nameWidth = (name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .medium), .kern: compact ? 1 : 2]).width
                let regionWidth = (city.region.uppercased() as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: compact ? 8 : 10), .kern: 1.6]).width
                let width = min(size.width - margin * 2, max(nameWidth, regionWidth) + 22)
                c.setFillColor(background.withAlphaComponent(0.95).cgColor)
                c.fill(CGRect(x: margin - 10, y: margin + 15, width: width, height: compact ? 49 : 69))
                text(name, at: CGPoint(x: margin, y: margin + (compact ? 39 : 48)), size: fontSize, color: ink, weight: .medium, tracking: compact ? 1 : 2)
                text(city.region.uppercased(), at: CGPoint(x: margin, y: margin + 24), size: compact ? 8 : 10, color: ink, tracking: 1.6)
            }
            let label = provider.attribution
            let fontSize: CGFloat = size.width < 300 ? 8 : 10
            let width = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: fontSize)]).width
            let x = max(6, size.width - margin - width)
            c.setFillColor(background.withAlphaComponent(0.96).cgColor)
            c.fill(CGRect(x: x - 7, y: margin - 5, width: width + 14, height: fontSize + 12))
            text(label, at: CGPoint(x: x, y: margin), size: fontSize, color: ink)
        }
    }
}
