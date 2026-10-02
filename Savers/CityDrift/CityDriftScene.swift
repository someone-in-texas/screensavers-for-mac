import AppKit
import CoreImage
import QuartzCore

final class CityDriftScene: SaverScene {
    static let cityDuration = 120.0
    static let transitionDuration = 1.5
    private var settings = SaverSettings()
    private let store: SettingsStore
    private let networkEnabled: Bool
    private let fixedCity: Bool
    private var hasStarted = false
    private(set) var city: MapCity
    private let fallbackCity: MapCity?
    private var loader: TileLoader?
    private var tiles: [TileID: CGImage] = [:]
    private var graded: [TileID: CGImage] = [:]
    private var tileLayers: [TilePlacement: CALayer] = [:]
    private var placements: [TilePlacement] = []
    private var fixture: CGImage?
    private var motion = MotionClock()
    private var fallbackMotion = MotionClock()
    private var vectorWasReady = false
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
    private var preparedVectorVisit: CachedVectorVisit?
    private let vectorSource: VectorMapSource
    private var vectorRevision = -1
    private var visitRequest = 0
    private var cacheRead: CityCacheRead?
    private var overlayLayer = CALayer()
    private var overlaySize = CGSize.zero
    private var overlayPixels = CGSize.zero
    private var overlayDirty = true
    private let provider: TileProvider
    private let tileCache: TileCache?
    private let tileTransport: TileTransport?
    init(store: SettingsStore, networkEnabled: Bool = true, city: MapCity? = nil, provider: TileProvider = .osm, starterMaps: StarterMaps = .bundled, visitCache: CityVisitCache? = nil, tileCache: TileCache? = nil, tileTransport: TileTransport? = nil, vectorCache: TileCache? = nil, vectorTransport: TileTransport? = nil) {
        self.store = store; self.networkEnabled = networkEnabled; self.provider = provider; self.fixedCity = city != nil
        self.starterMaps = provider.cacheNamespace == TileProvider.osm.cacheNamespace ? starterMaps : .empty
        self.vectorSource = VectorMapSource(networkEnabled: networkEnabled, cache: vectorCache, transport: vectorTransport)
        self.tileCache = tileCache; self.tileTransport = tileTransport
        self.visitCache = visitCache ?? CityVisitCache(cache: tileCache ?? TileCache(namespace: provider.cacheNamespace))
        self.reuseCache = networkEnabled || visitCache != nil
        self.settings = store.value
        let recent = store.defaults.stringArray(forKey: "recentCities") ?? []
        self.fallbackCity = self.starterMaps.catalog.filter { !recent.suffix(1).contains($0.name) }.randomElement() ?? self.starterMaps.catalog.first
        self.city = city ?? (networkEnabled && self.settings.mapStyle != .lines
            ? MapCity.choose(recent: recent) : self.fallbackCity ?? MapCity.choose(recent: recent))
        setCenter()
    }
    private func setCenter() {
        baseCenter = Mercator.point(latitude: city.latitude, longitude: city.longitude, zoom: city.zoom)
    }
    private var usesVectorMap: Bool {
        settings.mapStyle == .lines && fixture == nil
    }
    private var usesOnlineVector: Bool { settings.mapStyle == .online && fixture == nil && provider.cacheNamespace == TileProvider.osm.cacheNamespace }
    private var rendersVectors: Bool { usesVectorMap || usesOnlineVector }
    private func chooseDestination() -> MapCity {
        guard usesVectorMap else { return MapCity.choose(recent: store.defaults.stringArray(forKey: "recentCities") ?? []) }
        let recent = store.defaults.stringArray(forKey: "recentCities") ?? []
        let alternatives = starterMaps.catalog.filter { $0 != city }
        return alternatives.min { (recent.lastIndex(of: $0.name) ?? -1) < (recent.lastIndex(of: $1.name) ?? -1) } ?? city
    }
    private func beginCity(preloaded: [TileID: CGImage] = [:], keepOutgoing: Bool = true, vectorTiles: [TileID: VectorTile] = [:]) {
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
        if usesOnlineVector { vectorSource.begin(city: city, preloaded: vectorTiles) }
        tiles = preloaded; rasterReadyAtStart = !preloaded.isEmpty
        graded.removeAll(); placements.removeAll()
        tileLayers.removeAll()
        motion = MotionClock(); fallbackMotion = MotionClock(); vectorWasReady = false; tour = MotionClock(); overlayDirty = true; nextCity = nil; preparedVisit = nil; preparedVectorVisit = nil; visitRequest += 1; setCenter()
        var recent = store.defaults.stringArray(forKey: "recentCities") ?? []
        recent.append(city.name); store.defaults.set(Array(recent.suffix(8)), forKey: "recentCities")
        let session = generation
        if running && networkEnabled && !rendersVectors && loader == nil {
            loader = TileLoader(provider: provider, cache: tileCache, transport: tileTransport) { [weak self] id, image in
                guard let self, self.running, self.generation == session, self.placements.contains(where: { $0.id == id }) else { return }
                self.tiles[id] = image; self.graded.removeValue(forKey: id)
                // A stale cache refresh replaces its image without repeatedly fading the tile out.
            }
        }
    }
    func start() {
        guard !running else { return }
        if usesVectorMap && starterMaps[city] == nil, let fallbackCity { city = fallbackCity }
        if hasStarted && !fixedCity {
            city = usesVectorMap || !networkEnabled
                ? starterMaps.catalog.filter { $0 != city }.randomElement() ?? chooseDestination()
                : chooseDestination()
        }
        startupCachePending = reuseCache && !usesVectorMap; startupCacheRequested = false
        hasStarted = true; running = true; generation += 1; beginCity(keepOutgoing: false)
    }
    func stop() {
        running = false; generation += 1; loader?.stop(); loader = nil; vectorSource.stop()
        cacheRead?.cancel(); cacheRead = nil
        motion.pause(); fallbackMotion.pause(); tour.pause(); visitRequest += 1; preparedVisit = nil; preparedVectorVisit = nil
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
            loader?.stop(); loader = nil; vectorSource.stop()
            if usesVectorMap && starterMaps[city] == nil, let fallback = starterMaps.catalog.randomElement() { city = fallback }
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
            let vectors = preparedVectorVisit?.isUsable == true && preparedVectorVisit?.city == city && preparedVectorVisit?.viewport == lastViewport ? preparedVectorVisit?.tiles ?? [:] : [:]
            beginCity(preloaded: cached, vectorTiles: vectors)
            tour.step(now: time, speed: 1, maximumStep: .infinity)
        }
        // An unavailable destination must not leave a frozen outgoing scene forever.
        if !fixedCity, coverLayer != nil, coverFadeStart == nil, tour.elapsed > 20,
           starterMaps[city] == nil, let fallback = starterMaps.catalog.filter({ $0 != city }).randomElement() {
            city = fallback; beginCity(); tour.step(now: time, speed: 1, maximumStep: .infinity)
        }
        fallbackMotion.step(now: time, speed: settings.speed, maximumStep: 1.0 / 15)
        // Cache selection was built for time zero. Letting the camera move while
        // disk reads ran could immediately expose uncached tiles upon presentation.
        if startupCachePending || (usesOnlineVector && vectorSource.map == nil) { motion.pause() }
        else { motion.step(now: time, speed: settings.speed, maximumStep: 1.0 / 15) }
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
        // Vector geometry scales natively; use a bounded geographic viewport so
        // a Retina display does not quadruple network requests for identical detail.
        let viewport = rendersVectors ? Mercator.vectorRenderSize(size) : Mercator.mapRenderSize(size, backingScale: backingScale)
        if lastViewport != viewport {
            // A cache sufficient for a settings preview is not a complete fullscreen
            // map. Preserve the entire outgoing view while filling the larger one.
            if lastViewport != .zero && !rendersVectors && !placements.isEmpty { beginCity(preloaded: tiles) }
            cacheRead?.cancel(); cacheRead = nil
            lastViewport = viewport; visitRequest += 1; preparedVisit = nil; preparedVectorVisit = nil; nextCity = nil
            if startupCachePending { startupCacheRequested = false }
        }
        prepareCachedVisits(viewport: viewport)
        advance(time: time)
        let drift = Mercator.drift(motion.elapsed, bearing: city.longitude * .pi / 180)
        let center = CGPoint(x: baseCenter.x + drift.x, y: baseCenter.y + drift.y)
        let visible = Mercator.viewport(center: center, size: viewport, zoom: city.zoom)
        if visible != placements {
            placements = visible
            if running && !startupCachePending && !rendersVectors { loader?.request(visible.map(\.id)) }
            let current = Set(visible)
            for key in Array(tileLayers.keys) where !current.contains(key) {
                tileLayers.removeValue(forKey: key)?.removeFromSuperlayer()
            }
            // Resizes cannot accumulate unbounded decoded images; the disk cache retains reusable tiles.
            let retained = Set(visible.map(\.id))
            tiles = tiles.filter { retained.contains($0.key) }
            graded = graded.filter { retained.contains($0.key) }
        }
        if running && usesOnlineVector && !startupCachePending {
            vectorSource.configure(settings: settings, ink: ink, scale: backingScale * size.width / viewport.width)
            vectorSource.update(visible)
            if !vectorWasReady && vectorSource.map != nil {
                retainVectorFallbackForFade()
                vectorWasReady = true
            }
            if vectorRevision != vectorSource.revision { vectorRevision = vectorSource.revision; starterDirty = true }
        }
        return (center, viewport)
    }
    private func prepareCachedVisits(viewport: CGSize) {
        guard running, reuseCache, !usesVectorMap else { return }
        if usesOnlineVector { prepareVectorVisits(viewport: viewport); return }
        if startupCachePending && !startupCacheRequested {
            startupCacheRequested = true
            let request = visitRequest, session = generation
            cacheRead = visitCache.prepare(candidates: fixedCity ? [city] : startupCandidates(), viewport: viewport) { [weak self] visit in
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
    private func retainVectorFallbackForFade() {
        guard coverLayer == nil, let root = starterLayer.superlayer, !(starterLayer.sublayers ?? []).isEmpty else { return }
        let cover = CALayer(); cover.frame = CGRect(origin: .zero, size: lastSize)
        cover.backgroundColor = background.cgColor; cover.masksToBounds = true
        cover.addSublayer(starterLayer); cover.addSublayer(overlayLayer)
        coverLayer = cover; coverSize = lastSize; coverFadeStart = nil
        starterLayer = CALayer(); overlayLayer = CALayer(); overlayDirty = true
        root.insertSublayer(starterLayer, below: mapLayer); root.addSublayer(overlayLayer); root.addSublayer(cover)
    }
    private func prepareVectorVisits(viewport: CGSize) {
        let request = visitRequest, session = generation
        if startupCachePending && !startupCacheRequested {
            startupCacheRequested = true
            cacheRead = vectorSource.prepare(candidates: fixedCity ? [city] : startupCandidates(), viewport: viewport) { [weak self] visit in
                guard let self, self.running, self.generation == session, self.visitRequest == request else { return }
                self.startupCachePending = false
                if let visit, visit.isUsable { self.city = visit.city; self.beginCity(vectorTiles: visit.tiles) }
            }
        } else if !fixedCity && !startupCachePending && tour.elapsed >= Self.cityDuration - 20 && nextCity == nil {
            let destination = chooseDestination(); nextCity = destination
            cacheRead = vectorSource.prepare(candidates: [destination], viewport: viewport) { [weak self] visit in
                guard let self, self.running, self.generation == session, self.visitRequest == request else { return }
                self.preparedVectorVisit = visit
            }
        }
    }
    /// Online sessions should not be trapped in the same handful of cached cities.
    /// Offline previews can still reuse any complete recent viewport.
    private func startupCandidates() -> [MapCity] {
        let recent = store.defaults.stringArray(forKey: "recentCities") ?? []
        let candidates = MapCity.startupCandidates(recent: recent)
        return networkEnabled ? candidates.filter { $0 == city || !recent.contains($0.name) } : candidates
    }
    private var bundledMap: StarterMap? {
        starterMaps[city] ?? (fallbackCity.flatMap { starterMaps[$0] })
    }
    private var displayedCity: MapCity {
        if !usesVectorMap && vectorSource.map == nil && rasterFadeStart == nil && starterMaps[city] == nil {
            return fallbackCity ?? city
        }
        return city
    }
    private func updateStarter(scale: CGFloat) {
        if starterScale != scale { starterScale = scale; starterDirty = true }
        guard starterDirty else { return }
        starterLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        if usesOnlineVector && vectorSource.map != nil {
            for layer in vectorSource.layers { starterLayer.addSublayer(layer) }
        } else if let starter = bundledMap {
            let identity = city.name + (usesOnlineVector ? ":\(vectorRevision)" : "")
            if starterPathCity != identity {
                starterPaths = starter.paths(); starterPathCity = identity
            }
            let paths = starterPaths
            if rendersVectors {
                for layer in starter.detailLayers(settings: settings, ink: ink) { starterLayer.addSublayer(layer) }
            }
            for (kind, width) in [("minor", 0.65), ("tertiary", 1.0), ("secondary", 1.4), ("primary", 1.8), ("trunk", 2.2), ("motorway", 2.6)] {
                guard let path = paths[kind] else { continue }
                let road = CAShapeLayer(); road.name = "road"; road.path = path; road.fillColor = nil
                road.strokeColor = ink.cgColor
                road.lineWidth = width; road.lineCap = .round; road.lineJoin = .round
                starterLayer.addSublayer(road)
            }
            if rendersVectors {
                for layer in starter.labelLayers(settings: settings, ink: ink, scale: scale) { starterLayer.addSublayer(layer) }
            }
        }
        // Cache tessellation while the entire map translates at fractional positions.
        starterLayer.shouldRasterize = usesOnlineVector && vectorSource.map != nil; starterLayer.rasterizationScale = max(1, scale)
        starterDirty = false
    }
    private var completeViewport: Bool {
        usesOnlineVector ? vectorSource.complete : !placements.isEmpty && placements.allSatisfy { tiles[$0.id] != nil || fixture != nil }
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
        if usesOnlineVector && vectorSource.map == nil && bundledMap != nil {
            // The bundled scene keeps moving even while the first online viewport
            // is held steady for complete loading and repeatable cache startup.
            let drift = Mercator.drift(fallbackMotion.elapsed, bearing: city.longitude * .pi / 180)
            starterLayer.position = CGPoint(x: (viewport.width / 2 - drift.x) * size.width / viewport.width,
                                            y: (viewport.height / 2 + drift.y) * size.height / viewport.height)
        }
        if completeViewport && rasterFadeStart == nil { rasterFadeStart = rasterReadyAtStart ? time - 1.2 : time; overlayDirty = true }
        // Bundled maps stay visible until the whole raster viewport is available.
        // Never reveal an incomplete raster, even if only one tile is missing.
        // Keep an already visible map opaque as it moves; new visits start hidden.
        mapLayer.opacity = rendersVectors ? 0 : Float(rasterFadeStart.map { min(1, max(0, (time - $0) / 1.2)) } ?? 0)
        for tile in rendersVectors ? [] : placements {
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
        let overlayResolution = Mercator.mapRenderSize(size, backingScale: root.contentsScale)
        if overlaySize != size || overlayPixels != overlayResolution || overlayDirty {
            if let c = bitmap(width: Int(ceil(overlayResolution.width)), height: Int(ceil(overlayResolution.height))) {
                c.scaleBy(x: overlayResolution.width / size.width, y: overlayResolution.height / size.height)
                drawOverlays(in: c, size: size); overlayLayer.contents = c.makeImage()
            }
            overlayLayer.frame = CGRect(origin: .zero, size: size)
            overlaySize = size; overlayPixels = overlayResolution; overlayDirty = false
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
                let name = displayedCity.name.uppercased()
                let fontSize: CGFloat = compact ? 13 : 23
                let nameWidth = (name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .medium), .kern: compact ? 1 : 2]).width
                let regionWidth = (displayedCity.region.uppercased() as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: compact ? 8 : 10), .kern: 1.6]).width
                let width = min(size.width - margin * 2, max(nameWidth, regionWidth) + 22)
                c.setFillColor(background.withAlphaComponent(0.95).cgColor)
                c.fill(CGRect(x: margin - 10, y: margin + 15, width: width, height: compact ? 49 : 69))
                text(name, at: CGPoint(x: margin, y: margin + (compact ? 39 : 48)), size: fontSize, color: ink, weight: .medium, tracking: compact ? 1 : 2)
                text(displayedCity.region.uppercased(), at: CGPoint(x: margin, y: margin + 24), size: compact ? 8 : 10, color: ink, tracking: 1.6)
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
