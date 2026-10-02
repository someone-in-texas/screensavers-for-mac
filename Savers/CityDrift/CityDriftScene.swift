import AppKit
import CoreImage
import QuartzCore

final class CityDriftScene: SaverScene {
    static let cityDuration = 240.0
    static let transitionDuration = 1.5
    private var settings = SaverSettings()
    private let store: SettingsStore
    private let networkEnabled: Bool
    private let fixedCity: Bool
    private var hasStarted = false
    private(set) var city: MapCity
    private var loader: TileLoader?
    private var tiles: [TileID: CGImage] = [:]
    private var graded: [TileID: CGImage] = [:]
    private var tileLayers: [TilePlacement: CALayer] = [:]
    private var arrivals: [TileID: Double] = [:]
    private var placements: [TilePlacement] = []
    private var fixture: CGImage?
    private var motion = MotionClock()
    private var tour = MotionClock()
    private var running = false
    private var generation = 0
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var baseCenter = CGPoint.zero
    private let mapLayer = CALayer()
    private let overlayLayer = CALayer()
    private var overlaySize = CGSize.zero
    private var overlayPixels = CGSize.zero
    private var overlayDirty = true
    private let provider: TileProvider
    init(store: SettingsStore, networkEnabled: Bool = true, city: MapCity? = nil, provider: TileProvider = .osm) {
        self.store = store; self.networkEnabled = networkEnabled; self.provider = provider; self.fixedCity = city != nil
        self.city = city ?? MapCity.choose(recent: store.defaults.stringArray(forKey: "recentCities") ?? [])
        setCenter()
    }
    private func setCenter() {
        baseCenter = Mercator.point(latitude: city.latitude, longitude: city.longitude, zoom: city.zoom)
    }
    private func beginCity() {
        loader?.beginVisit()
        tiles.removeAll(); graded.removeAll(); arrivals.removeAll(); placements.removeAll()
        tileLayers.values.forEach { $0.removeFromSuperlayer() }; tileLayers.removeAll()
        motion = MotionClock(); tour = MotionClock(); overlayDirty = true; setCenter()
        var recent = store.defaults.stringArray(forKey: "recentCities") ?? []
        recent.append(city.name); store.defaults.set(Array(recent.suffix(8)), forKey: "recentCities")
        let session = generation
        if networkEnabled && loader == nil {
            loader = TileLoader(provider: provider) { [weak self] id, image in
                guard let self, self.running, self.generation == session, self.placements.contains(where: { $0.id == id }) else { return }
                self.tiles[id] = image; self.graded.removeValue(forKey: id)
                // A stale cache refresh replaces its image without repeatedly fading the tile out.
            }
        }
    }
    func start() {
        guard !running else { return }
        if hasStarted && !fixedCity {
            city = MapCity.choose(recent: store.defaults.stringArray(forKey: "recentCities") ?? [])
        }
        hasStarted = true; running = true; generation += 1; beginCity()
    }
    func stop() {
        running = false; generation += 1; loader?.stop(); loader = nil
        motion.pause(); tour.pause()
    }
    func apply(_ settings: SaverSettings) {
        if self.settings.palette != settings.palette || self.settings.intensity != settings.intensity || self.settings.grain != settings.grain {
            graded.removeAll()
        }
        overlayDirty = overlayDirty || self.settings != settings
        self.settings = settings
    }
    /// Deterministic synthetic cartography for automated smoke tests; never contacts OSM.
    func useFixture(_ image: CGImage) { fixture = image; graded.removeAll() }
    /// Separate active-time clocks keep city changes independent of the camera speed.
    /// Called by both renderers, and directly by long-session regression tests.
    func advance(time: Double) {
        guard running else { return }
        tour.step(now: time, speed: 1, maximumStep: .infinity)
        if !fixedCity && tour.elapsed >= Self.cityDuration + Self.transitionDuration {
            city = MapCity.choose(recent: store.defaults.stringArray(forKey: "recentCities") ?? [])
            beginCity()
            tour.step(now: time, speed: 1, maximumStep: .infinity)
        }
        motion.step(now: time, speed: settings.speed)
    }
    var transitionOpacity: Double {
        fixedCity ? 1 : max(0, min(1, (Self.cityDuration + Self.transitionDuration - tour.elapsed) / Self.transitionDuration))
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
    private func image(for id: TileID) -> CGImage? {
        if let image = graded[id] { return image }
        guard let raw = tiles[id] ?? fixture else { return nil }
        if settings.palette == .original && !settings.grain { graded[id] = raw; return raw }
        let input = CIImage(cgImage: raw)
        var output = input
        if settings.palette != .original {
            let dark = [.blueprint, .night, .terminal].contains(settings.palette)
            if dark {
                output = input.clampedToExtent().applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                    .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 1.7])
                    .applyingFilter("CIFalseColor", parameters: ["inputColor0": CIColor(color: background)!, "inputColor1": CIColor(color: ink)!])
            } else {
                output = input.clampedToExtent().applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.18])
                    .applyingFilter("CIFalseColor", parameters: ["inputColor0": CIColor(color: ink)!, "inputColor1": CIColor(color: background)!])
            }
        }
        guard let filtered = imageContext.createCGImage(output, from: input.extent), let c = bitmap(width: 256, height: 256) else { return raw }
        c.draw(raw, in: CGRect(x: 0, y: 0, width: 256, height: 256))
        c.setAlpha(settings.palette == .original ? 1 : settings.intensity)
        c.draw(filtered, in: CGRect(x: 0, y: 0, width: 256, height: 256)); c.setAlpha(1)
        if settings.grain {
            var seed: UInt64 = 47
            c.setFillColor(ink.withAlphaComponent(0.035).cgColor)
            for _ in 0..<260 {
                seed = seed &* 6364136223846793005 &+ 1; let x = Int((seed >> 32) % 256)
                seed = seed &* 6364136223846793005 &+ 1; let y = Int((seed >> 32) % 256)
                c.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        let result = c.makeImage() ?? raw; graded[id] = result; return result
    }
    private func prepare(size: CGSize, backingScale: CGFloat, time: Double) -> (CGPoint, CGSize) {
        advance(time: time)
        let drift = Mercator.drift(motion.elapsed, bearing: city.longitude * .pi / 180)
        let center = CGPoint(x: baseCenter.x + drift.x, y: baseCenter.y + drift.y)
        let viewport = Mercator.mapRenderSize(size, backingScale: backingScale)
        let visible = Mercator.viewport(center: center, size: viewport, zoom: city.zoom)
        if visible != placements {
            placements = visible
            if running { loader?.request(visible.map(\.id)) }
            let current = Set(visible)
            for key in Array(tileLayers.keys) where !current.contains(key) {
                tileLayers.removeValue(forKey: key)?.removeFromSuperlayer()
            }
            // Resizes cannot accumulate unbounded decoded images; the disk cache retains reusable tiles.
            let retained = Set(visible.map(\.id))
            tiles = tiles.filter { retained.contains($0.key) }
            graded = graded.filter { retained.contains($0.key) }
            arrivals = arrivals.filter { retained.contains($0.key) }
        }
        return (center, viewport)
    }
    private func rect(for tile: TilePlacement, center: CGPoint, viewport: CGSize) -> CGRect {
        CGRect(x: CGFloat(tile.x * 256) - center.x + viewport.width / 2,
               y: center.y + viewport.height / 2 - CGFloat((tile.y + 1) * 256), width: 256, height: 256)
    }
    private func opacity(for id: TileID, time: Double) -> Float {
        if arrivals[id] == nil { arrivals[id] = time }
        return Float(min(1, max(0, (time - arrivals[id]!) / 1.2)))
    }
    func updateLayer(_ root: CALayer, size: CGSize, time: Double, date: Date) -> Bool {
        let (center, viewport) = prepare(size: size, backingScale: root.contentsScale, time: time)
        if mapLayer.superlayer !== root {
            root.masksToBounds = true; root.addSublayer(mapLayer); root.addSublayer(overlayLayer)
        }
        root.backgroundColor = background.cgColor
        mapLayer.anchorPoint = .zero
        mapLayer.position = CGPoint(x: (viewport.width / 2 - center.x + baseCenter.x) * size.width / viewport.width,
                                    y: (viewport.height / 2 + center.y - baseCenter.y) * size.height / viewport.height)
        mapLayer.bounds = CGRect(origin: .zero, size: viewport)
        mapLayer.setAffineTransform(CGAffineTransform(scaleX: size.width / viewport.width, y: size.height / viewport.height))
        mapLayer.opacity = Float(transitionOpacity)
        for tile in placements {
            guard let image = image(for: tile.id) else { continue }
            let layer: CALayer
            if let existing = tileLayers[tile] { layer = existing }
            else {
                layer = CALayer(); layer.minificationFilter = .linear; layer.magnificationFilter = .linear
                layer.frame = CGRect(x: CGFloat(tile.x * 256) - baseCenter.x,
                                     y: baseCenter.y - CGFloat((tile.y + 1) * 256), width: 256, height: 256)
                tileLayers[tile] = layer; mapLayer.addSublayer(layer)
            }
            if layer.contents as AnyObject? !== image { layer.contents = image }
            let alpha = opacity(for: tile.id, time: time)
            if layer.opacity != alpha { layer.opacity = alpha }
        }
        if overlaySize != size || overlayPixels != viewport || overlayDirty {
            if let c = bitmap(width: Int(ceil(viewport.width)), height: Int(ceil(viewport.height))) {
                c.scaleBy(x: viewport.width / size.width, y: viewport.height / size.height)
                drawOverlays(in: c, size: size); overlayLayer.contents = c.makeImage()
            }
            overlayLayer.frame = CGRect(origin: .zero, size: size)
            overlaySize = size; overlayPixels = viewport; overlayDirty = false
        }
        return true
    }
    func draw(in c: CGContext, size: CGSize, time: Double, date: Date) {
        let (center, viewport) = prepare(size: size, backingScale: 1, time: time)
        c.setFillColor(background.cgColor); c.fill(CGRect(origin: .zero, size: size))
        c.saveGState(); c.scaleBy(x: size.width / viewport.width, y: size.height / viewport.height)
        for tile in placements {
            guard let image = image(for: tile.id) else { continue }
            c.setAlpha(CGFloat(opacity(for: tile.id, time: time)) * transitionOpacity)
            c.draw(image, in: rect(for: tile, center: center, viewport: viewport))
        }
        c.restoreGState(); drawOverlays(in: c, size: size)
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
