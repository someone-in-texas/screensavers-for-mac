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
    private var placements: [TilePlacement] = []
    private var fixture: CGImage?
    private var motion = MotionClock()
    private var tour = MotionClock()
    private var running = false
    private var generation = 0
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var baseCenter = CGPoint.zero
    private var mapLayer = CALayer()
    private var starterLayer = CALayer()
    private var coverLayer: CALayer?
    private var coverSize = CGSize.zero
    private var coverFadeStart: Double?
    private var rasterFadeStart: Double?
    private var rasterReadyAtStart = false
    private var starterDirty = true
    private var starterScale: CGFloat = 0
    private var starterPathCity: String?
    private var starterPaths: [String: CGPath] = [:]
    private var lastSize = CGSize.zero
    private var lastViewport = CGSize.zero
    private let starterMaps: StarterMaps
    private let visitCache: CityVisitCache
    private let reuseCache: Bool
    private var startupCachePending = false
    private var startupCacheRequested = false
    private var nextCity: MapCity?
    private var preparedVisit: CachedCityVisit?
    private var visitRequest = 0
    private var cacheRead: CityCacheRead?
    private var overlayLayer = CALayer()
    private var overlaySize = CGSize.zero
    private var overlayPixels = CGSize.zero
    private var overlayDirty = true
    private let provider: TileProvider
    private let tileCache: TileCache?
    private let tileTransport: TileTransport?
    init(store: SettingsStore, networkEnabled: Bool = true, city: MapCity? = nil, provider: TileProvider = .osm, starterMaps: StarterMaps = .bundled, visitCache: CityVisitCache? = nil, tileCache: TileCache? = nil, tileTransport: TileTransport? = nil) {
        self.store = store; self.networkEnabled = networkEnabled; self.provider = provider; self.fixedCity = city != nil
        self.starterMaps = provider.cacheNamespace == TileProvider.osm.cacheNamespace ? starterMaps : .empty
        self.tileCache = tileCache; self.tileTransport = tileTransport
        self.visitCache = visitCache ?? CityVisitCache(cache: tileCache ?? TileCache(namespace: provider.cacheNamespace))
        self.reuseCache = networkEnabled || visitCache != nil
        self.settings = store.value
        self.city = city ?? self.starterMaps.catalog.randomElement() ?? MapCity.choose(recent: store.defaults.stringArray(forKey: "recentCities") ?? [])
        setCenter()
    }
    private func setCenter() {
        baseCenter = Mercator.point(latitude: city.latitude, longitude: city.longitude, zoom: city.zoom)
    }
    private var usesVectorMap: Bool {
        settings.mapStyle == .lines && !starterMaps.cities.isEmpty && fixture == nil && (!fixedCity || starterMaps[city] != nil)
    }
    private func chooseDestination() -> MapCity {
        guard usesVectorMap else { return MapCity.choose(recent: store.defaults.stringArray(forKey: "recentCities") ?? []) }
        let recent = store.defaults.stringArray(forKey: "recentCities") ?? []
        let alternatives = starterMaps.catalog.filter { $0 != city }
        return alternatives.min { (recent.lastIndex(of: $0.name) ?? -1) < (recent.lastIndex(of: $1.name) ?? -1) } ?? city
    }
    private func beginCity(preloaded: [TileID: CGImage] = [:], keepOutgoing: Bool = true) {
        // Keep the complete outgoing scene until the next scene is ready. Retain one
        // layer tree rather than taking a giant screenshot or prefetching network tiles.
        if !keepOutgoing { coverLayer?.removeFromSuperlayer(); coverLayer = nil }
        if keepOutgoing, let root = mapLayer.superlayer, coverLayer == nil {
            let cover = CALayer(); cover.frame = CGRect(origin: .zero, size: lastSize)
            cover.backgroundColor = background.cgColor; cover.masksToBounds = true
            cover.addSublayer(starterLayer); cover.addSublayer(mapLayer); cover.addSublayer(overlayLayer)
            root.addSublayer(cover); coverLayer = cover; coverSize = lastSize
        } else {
            starterLayer.removeFromSuperlayer(); mapLayer.removeFromSuperlayer(); overlayLayer.removeFromSuperlayer()
        }
        starterLayer = CALayer(); mapLayer = CALayer(); overlayLayer = CALayer()
        coverFadeStart = nil; rasterFadeStart = nil; starterDirty = true
        cacheRead?.cancel(); cacheRead = nil
        loader?.beginVisit()
        tiles = preloaded; rasterReadyAtStart = !preloaded.isEmpty
        graded.removeAll(); placements.removeAll()
        tileLayers.removeAll()
        motion = MotionClock(); tour = MotionClock(); overlayDirty = true; nextCity = nil; preparedVisit = nil; visitRequest += 1; setCenter()
        var recent = store.defaults.stringArray(forKey: "recentCities") ?? []
        recent.append(city.name); store.defaults.set(Array(recent.suffix(8)), forKey: "recentCities")
        let session = generation
        if networkEnabled && !usesVectorMap && loader == nil {
            loader = TileLoader(provider: provider, cache: tileCache, transport: tileTransport) { [weak self] id, image in
                guard let self, self.running, self.generation == session, self.placements.contains(where: { $0.id == id }) else { return }
                self.tiles[id] = image; self.graded.removeValue(forKey: id)
                // A stale cache refresh replaces its image without repeatedly fading the tile out.
            }
        }
    }
    func start() {
        guard !running else { return }
        if hasStarted && !fixedCity {
            city = starterMaps.catalog.filter { $0 != city }.randomElement() ?? MapCity.choose(recent: store.defaults.stringArray(forKey: "recentCities") ?? [])
        }
        startupCachePending = reuseCache && !usesVectorMap; startupCacheRequested = false
        hasStarted = true; running = true; generation += 1; beginCity(keepOutgoing: false)
    }
    func stop() {
        running = false; generation += 1; loader?.stop(); loader = nil
        cacheRead?.cancel(); cacheRead = nil
        motion.pause(); tour.pause(); visitRequest += 1; preparedVisit = nil
        coverLayer?.removeFromSuperlayer(); coverLayer = nil
    }
    func apply(_ settings: SaverSettings) {
        let changedStyle = self.settings.mapStyle != settings.mapStyle
        if self.settings.palette != settings.palette || self.settings.intensity != settings.intensity || self.settings.grain != settings.grain {
            graded.removeAll()
        }
        starterDirty = starterDirty || changedStyle || self.settings.palette != settings.palette ||
            self.settings.streetLabels != settings.streetLabels || self.settings.water != settings.water ||
            self.settings.parks != settings.parks || self.settings.pointsOfInterest != settings.pointsOfInterest
        overlayDirty = overlayDirty || self.settings != settings
        self.settings = settings
        if changedStyle && running {
            loader?.stop(); loader = nil
            if usesVectorMap && starterMaps[city] == nil { city = starterMaps.catalog.randomElement()! }
            startupCachePending = reuseCache && !usesVectorMap; startupCacheRequested = false
            beginCity()
        }
    }
    /// Deterministic synthetic cartography for automated smoke tests; never contacts OSM.
    func useFixture(_ image: CGImage) { fixture = image; graded.removeAll() }
    /// Separate active-time clocks keep city changes independent of the camera speed.
    /// Called by both renderers, and directly by long-session regression tests.
    func advance(time: Double) {
        guard running else { return }
        tour.step(now: time, speed: 1, maximumStep: .infinity)
        if !fixedCity && tour.elapsed >= Self.cityDuration + Self.transitionDuration {
            city = nextCity ?? chooseDestination()
            let cached = preparedVisit?.isUsable == true && preparedVisit?.city == city && preparedVisit?.viewport == lastViewport ? preparedVisit?.images ?? [:] : [:]
            beginCity(preloaded: cached)
            tour.step(now: time, speed: 1, maximumStep: .infinity)
        }
        // An unavailable destination must not leave a frozen outgoing scene forever.
        if !fixedCity, coverLayer != nil, coverFadeStart == nil, tour.elapsed > 20,
           starterMaps[city] == nil, let fallback = starterMaps.catalog.filter({ $0 != city }).randomElement() {
            city = fallback; beginCity(); tour.step(now: time, speed: 1, maximumStep: .infinity)
        }
        // Cache selection was built for time zero. Letting the camera move while
        // disk reads ran could immediately expose uncached tiles upon presentation.
        if startupCachePending { motion.pause() }
        else { motion.step(now: time, speed: settings.speed) }
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
        guard let c = bitmap(width: 256, height: 256) else { return raw }
        c.setFillColor(NSColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
        c.draw(raw, in: CGRect(x: 0, y: 0, width: 256, height: 256))
        if [.blueprint, .night, .terminal].contains(settings.palette) {
            // A pointwise sRGB tint preserves antialiased strokes. Edge detection used
            // to outline every glyph twice and depended on where tiles were cut.
            DarkMapTint.apply(to: c, background: RGB(background), ink: RGB(ink), intensity: settings.intensity)
        } else if settings.palette != .original {
            let input = CIImage(cgImage: raw)
            let output = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.18])
                .applyingFilter("CIFalseColor", parameters: ["inputColor0": CIColor(color: ink)!, "inputColor1": CIColor(color: background)!])
            if let filtered = imageContext.createCGImage(output, from: input.extent) {
                c.setAlpha(settings.intensity)
                c.draw(filtered, in: CGRect(x: 0, y: 0, width: 256, height: 256)); c.setAlpha(1)
            }
        }
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
        let viewport = Mercator.mapRenderSize(size, backingScale: backingScale)
        if lastViewport != viewport {
            // A cache sufficient for a settings preview is not a complete fullscreen
            // map. Preserve the entire outgoing view while filling the larger one.
            if lastViewport != .zero && !usesVectorMap && !placements.isEmpty { beginCity(preloaded: tiles) }
            cacheRead?.cancel(); cacheRead = nil
            lastViewport = viewport; visitRequest += 1; preparedVisit = nil; nextCity = nil
            if startupCachePending { startupCacheRequested = false }
        }
        prepareCachedVisits(viewport: viewport)
        advance(time: time)
        let drift = Mercator.drift(motion.elapsed, bearing: city.longitude * .pi / 180)
        let center = CGPoint(x: baseCenter.x + drift.x, y: baseCenter.y + drift.y)
        let visible = Mercator.viewport(center: center, size: viewport, zoom: city.zoom)
        if visible != placements {
            placements = visible
            if running && !startupCachePending && !usesVectorMap { loader?.request(visible.map(\.id)) }
            let current = Set(visible)
            for key in Array(tileLayers.keys) where !current.contains(key) {
                tileLayers.removeValue(forKey: key)?.removeFromSuperlayer()
            }
            // Resizes cannot accumulate unbounded decoded images; the disk cache retains reusable tiles.
            let retained = Set(visible.map(\.id))
            tiles = tiles.filter { retained.contains($0.key) }
            graded = graded.filter { retained.contains($0.key) }
        }
        return (center, viewport)
    }
    private func prepareCachedVisits(viewport: CGSize) {
        guard running, reuseCache, !usesVectorMap else { return }
        if startupCachePending && !startupCacheRequested {
            startupCacheRequested = true
            let request = visitRequest, session = generation
            cacheRead = visitCache.prepare(candidates: fixedCity ? [city] : MapCity.all.shuffled(), viewport: viewport) { [weak self] visit in
                guard let self, self.running, self.generation == session, self.visitRequest == request else { return }
                self.startupCachePending = false
                if let visit, visit.isUsable {
                    self.city = visit.city; self.beginCity(preloaded: visit.images)
                } else { self.placements = [] }
            }
        } else if !fixedCity && !startupCachePending && tour.elapsed >= Self.cityDuration - 20 && nextCity == nil {
            let destination = MapCity.choose(recent: store.defaults.stringArray(forKey: "recentCities") ?? [])
            nextCity = destination
            let request = visitRequest, session = generation
            cacheRead = visitCache.prepare(candidates: [destination], viewport: viewport) { [weak self] visit in
                guard let self, self.running, self.generation == session, self.visitRequest == request else { return }
                self.preparedVisit = visit
            }
        }
    }
    private func updateStarter(scale: CGFloat) {
        if starterScale != scale { starterScale = scale; starterDirty = true }
        guard starterDirty else { return }
        starterLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        if let starter = starterMaps[city] {
            if starterPathCity != city.name {
                starterPaths = starter.paths(); starterPathCity = city.name
            }
            let paths = starterPaths
            if usesVectorMap {
                for layer in starter.detailLayers(settings: settings, ink: ink) { starterLayer.addSublayer(layer) }
            }
            for (kind, width) in [("tertiary", 1.0), ("secondary", 1.4), ("primary", 1.8), ("trunk", 2.2), ("motorway", 2.6)] {
                guard let path = paths[kind] else { continue }
                let road = CAShapeLayer(); road.name = "road"; road.path = path; road.fillColor = nil
                road.strokeColor = ink.cgColor
                road.lineWidth = width; road.lineCap = .round; road.lineJoin = .round
                starterLayer.addSublayer(road)
            }
            if usesVectorMap {
                for layer in starter.labelLayers(settings: settings, ink: ink, scale: scale) { starterLayer.addSublayer(layer) }
            }
        }
        starterDirty = false
    }
    private var completeViewport: Bool {
        !placements.isEmpty && placements.allSatisfy { tiles[$0.id] != nil || fixture != nil }
    }
    func updateLayer(_ root: CALayer, size: CGSize, time: Double, date: Date) -> Bool {
        let (center, viewport) = prepare(size: size, backingScale: root.contentsScale, time: time)
        if mapLayer.superlayer !== root {
            root.masksToBounds = true; root.addSublayer(starterLayer); root.addSublayer(mapLayer); root.addSublayer(overlayLayer)
            if let coverLayer { root.addSublayer(coverLayer) }
        }
        root.backgroundColor = background.cgColor
        mapLayer.anchorPoint = .zero
        mapLayer.position = CGPoint(x: (viewport.width / 2 - center.x + baseCenter.x) * size.width / viewport.width,
                                    y: (viewport.height / 2 + center.y - baseCenter.y) * size.height / viewport.height)
        mapLayer.bounds = CGRect(origin: .zero, size: viewport)
        mapLayer.setAffineTransform(CGAffineTransform(scaleX: size.width / viewport.width, y: size.height / viewport.height))
        lastSize = size
        updateStarter(scale: root.contentsScale * size.width / viewport.width)
        starterLayer.anchorPoint = .zero; starterLayer.bounds = mapLayer.bounds
        starterLayer.position = mapLayer.position; starterLayer.setAffineTransform(mapLayer.affineTransform())
        if completeViewport && rasterFadeStart == nil { rasterFadeStart = rasterReadyAtStart ? time - 1.2 : time }
        // Bundled maps stay visible until the whole raster viewport is available.
        // Never reveal an incomplete raster, even if only one tile is missing.
        // Keep an already visible map opaque as it moves; new visits start hidden.
        mapLayer.opacity = usesVectorMap ? 0 : Float(rasterFadeStart.map { min(1, max(0, (time - $0) / 1.2)) } ?? 0)
        for tile in usesVectorMap ? [] : placements {
            guard let image = image(for: tile.id) else { continue }
            let layer: CALayer
            if let existing = tileLayers[tile] { layer = existing }
            else {
                layer = CALayer(); layer.isOpaque = true; layer.allowsEdgeAntialiasing = false; layer.edgeAntialiasingMask = []
                layer.minificationFilter = .linear; layer.magnificationFilter = .linear
                layer.frame = CGRect(x: CGFloat(tile.x * 256) - baseCenter.x,
                                     y: baseCenter.y - CGFloat((tile.y + 1) * 256), width: 256, height: 256)
                tileLayers[tile] = layer; mapLayer.addSublayer(layer)
            }
            if layer.contents as AnyObject? !== image { layer.contents = image }
            layer.opacity = 1
        }
        if overlaySize != size || overlayPixels != viewport || overlayDirty {
            if let c = bitmap(width: Int(ceil(viewport.width)), height: Int(ceil(viewport.height))) {
                c.scaleBy(x: viewport.width / size.width, y: viewport.height / size.height)
                drawOverlays(in: c, size: size); overlayLayer.contents = c.makeImage()
            }
            overlayLayer.frame = CGRect(origin: .zero, size: size)
            overlaySize = size; overlayPixels = viewport; overlayDirty = false
        }
        if let cover = coverLayer {
            if coverFadeStart == nil && (completeViewport || starterMaps[city] != nil) { coverFadeStart = time }
            if let start = coverFadeStart {
                cover.opacity = Float(max(0, 1 - (time - start) / Self.transitionDuration))
                if cover.opacity == 0 { cover.removeFromSuperlayer(); coverLayer = nil }
            }
            if coverSize.width > 0 && coverSize.height > 0 {
                cover.anchorPoint = .zero; cover.position = .zero
                cover.setAffineTransform(CGAffineTransform(scaleX: size.width / coverSize.width, y: size.height / coverSize.height))
            }
        }
        return true
    }
    func draw(in c: CGContext, size: CGSize, time: Double, date: Date) {
        let root = CALayer(); root.bounds = CGRect(origin: .zero, size: size)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        _ = updateLayer(root, size: size, time: time, date: date)
        root.render(in: c); CATransaction.commit()
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
