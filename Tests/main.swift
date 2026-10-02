import AppKit
import Foundation

var checks = 0
var failures = 0
func expect(_ value: @autoclosure () -> Bool, _ name: String, file: String = #file, line: Int = #line) {
    checks += 1
    if !value() { failures += 1; print("FAIL \(file):\(line): \(name)") }
}
func near(_ a: Double, _ b: Double, _ name: String, tolerance: Double = 0.00001) { expect(abs(a - b) < tolerance, name) }
func waitUntil(_ predicate: () -> Bool, timeout: Double = 3) {
    let deadline = Date().addingTimeInterval(timeout)
    while !predicate() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
}
func response(_ status: Int = 200, _ headers: [String: String] = [:]) -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: "https://tile.openstreetmap.org/1/0/0.png")!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
}
func tilePNG() -> Data {
    let c = bitmap(width: 256, height: 256)!; c.setFillColor(NSColor.white.cgColor); c.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
    return NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!
}
final class Cancellation: TileCancellation {
    private let lock = NSLock()
    private var value = false
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
    func cancel() { lock.lock(); value = true; lock.unlock() }
}
final class MockTransport: TileTransport {
    struct Call { let request: URLRequest; let token: Cancellation; let completion: (Data?, HTTPURLResponse?, Error?) -> Void }
    private let lock = NSLock()
    private var storage: [Call] = []
    var calls: [Call] { lock.lock(); defer { lock.unlock() }; return storage }
    func fetch(_ request: URLRequest, completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) -> TileCancellation {
        let token = Cancellation(); lock.lock(); storage.append(Call(request: request, token: token, completion: completion)); lock.unlock(); return token
    }
}

// Settings: defaults, persistent round-trip, corruption, range validation, distinct modules.
let suiteA = "screensavers.tests.a.\(UUID().uuidString)"
let suiteB = "screensavers.tests.b.\(UUID().uuidString)"
let defaultsA = UserDefaults(suiteName: suiteA)!, defaultsB = UserDefaults(suiteName: suiteB)!
defer { defaultsA.removePersistentDomain(forName: suiteA); defaultsB.removePersistentDomain(forName: suiteB) }
let a = SettingsStore(.worldClockRoom, defaults: defaultsA), b = SettingsStore(.cityDrift, defaults: defaultsB)
expect(a.value == SaverSettings(), "default settings")
var value = a.value; value.speed = 1.7; value.palette = .blueprint; value.floor = RGB(0.1, 0.2, 0.3)
a.value = value
expect(SettingsStore(.worldClockRoom, defaults: UserDefaults(suiteName: suiteA)!).value == value, "persistent round-trip")
expect(b.value == SaverSettings(), "settings are isolated")
expect(SaverKind.worldClockRoom.identifier != SaverKind.cityDrift.identifier, "unique production domains")
value.speed = .infinity; value.density = -500; value.floor = RGB(-1, 8, 3)
expect(value.sanitized().speed == 6 && value.sanitized().density == 0.7 && value.sanitized().floor == SaverSettings().floor, "sanitize invalid settings")
defaultsA.set(Data("invalid".utf8), forKey: "settings.v2"); expect(a.value == SaverSettings(), "corrupt settings fallback")
a.value = value.sanitized(); a.reset(); expect(a.value == SaverSettings(), "reset defaults")

// Upgrade existing appearance preferences once, including an explicitly paused camera.
var legacy = SaverSettings(); legacy.speed = 1.5; legacy.palette = .terminal
try! defaultsA.set(JSONEncoder().encode(legacy), forKey: "settings.v1")
expect(a.value.speed == 9 && a.value.palette == .terminal, "legacy motion upgrade preserves appearance")
expect(a.value.speed == 9, "migration is not applied twice")
a.reset(); legacy.speed = 0
try! defaultsA.set(JSONEncoder().encode(legacy), forKey: "settings.v1")
expect(a.value.speed == 0, "migration preserves pause")
a.reset()
expect(SaverSettings().speed == 6 && SaverSettings.maximumSpeed == 16, "new motion defaults and range")

// Wall time and DST use Calendar + IANA zones, not a table of offsets.
expect(ClockCity.all.count == 20, "clock catalog size")
expect(ClockCity.all.allSatisfy { TimeZone(identifier: $0.identifier) != nil }, "valid IANA identifiers")
var chicago = Calendar(identifier: .gregorian); chicago.timeZone = TimeZone(identifier: "America/Chicago")!
let iso = ISO8601DateFormatter()
let before = iso.date(from: "2026-03-08T07:59:59Z")!, after = iso.date(from: "2026-03-08T08:00:00Z")!
expect(chicago.component(.hour, from: before) == 1 && chicago.component(.hour, from: after) == 3, "spring DST skip")
let fallA = iso.date(from: "2026-11-01T06:30:00Z")!, fallB = iso.date(from: "2026-11-01T07:30:00Z")!
near(HandAngles(date: fallA, calendar: chicago, smooth: true).hour, HandAngles(date: fallB, calendar: chicago, smooth: true).hour, "fall repeated hour")
var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
let fixed = iso.date(from: "2026-06-01T03:15:30Z")!.addingTimeInterval(0.5)
let hands = HandAngles(date: fixed, calendar: utc, smooth: true)
near(hands.second, 30.5 / 60 * .pi * 2, "fractional seconds")
near(hands.minute, (15 + 30.5 / 60) / 60 * .pi * 2, "fractional minutes")
near(hands.hour, (3 + (15 + 30.5 / 60) / 60) / 12 * .pi * 2, "fractional hours")
near(HandAngles(date: fixed, calendar: utc, smooth: false).second, .pi, "ticking seconds")
var india = utc; india.timeZone = TimeZone(identifier: "Asia/Kolkata")!
expect(india.component(.minute, from: fixed) == 45, "half-hour zones")
let projected = Iso.project(3, -2), original = Iso.unproject(projected)
near(original.x, 3, "isometric inverse x"); near(original.y, -2, "isometric inverse y")
near(Iso.project(1, 0).y, 0.5, "isometric depth")
expect(Iso.cityIndex(x: -100, y: -33, count: 20) == Iso.cityIndex(x: -100, y: -33, count: 20), "deterministic layout")
expect((-20...20).allSatisfy { (0..<20).contains(Iso.cityIndex(x: $0, y: -$0, count: 20)) }, "negative grid indices")
var motion = MotionClock(); motion.step(now: 10, speed: 1); motion.step(now: 10.1, speed: 1); motion.step(now: 10.2, speed: 2)
near(motion.elapsed, 0.3, "speed integration preserves continuity")
motion.pause(); motion.step(now: 10000, speed: 1); near(motion.elapsed, 0.3, "pause excludes stopped time")

// Mercator, poles, wrapping, visible tile sets, bounded drift at every tested aspect.
let zero = Mercator.point(latitude: 0, longitude: 0, zoom: 1)
near(zero.x, 256, "Mercator equator x"); near(zero.y, 256, "Mercator equator y")
near(Mercator.point(latitude: 90, longitude: 180, zoom: 1).x, 0, "longitude wraps")
expect(abs(Mercator.point(latitude: 90, longitude: 0, zoom: 1).y) < 0.0001, "latitude clamped")
expect(TileID(z: 2, x: -1, y: 0)?.x == 3, "tile x wraps")
expect(TileID(z: 2, x: 0, y: -1) == nil && TileID(z: 2, x: 0, y: 4) == nil && TileID(z: 24, x: 0, y: 0) == nil, "invalid tile rejection")
let tile = TileID(z: 14, x: 8192, y: 8191)!
expect(tile.key == "14-8192-8191", "stable cache key")
expect(TileProvider.osm.url(tile)?.absoluteString == "https://tile.openstreetmap.org/14/8192/8191.png", "OSM URL")
expect(TileProvider(template: "http://example.com/{z}/{x}/{y}", cacheNamespace: "test", attribution: "test").url(tile) == nil, "reject HTTP")
let exact = Mercator.viewport(center: CGPoint(x: 384, y: 384), size: CGSize(width: 256, height: 256), zoom: 2)
expect(exact.count == 1 && exact[0].id == TileID(z: 2, x: 1, y: 1), "no unnecessary edge tiles")
let wrapped = Mercator.viewport(center: CGPoint(x: 0, y: 256), size: CGSize(width: 512, height: 256), zoom: 2)
expect(Set(wrapped.map { $0.id.x }) == Set([0, 3]), "viewport antimeridian wrap")
for dimensions in [CGSize(width: 5120, height: 2880), CGSize(width: 3440, height: 1440), CGSize(width: 200, height: 300), CGSize(width: 1000, height: 5000)] {
    let capped = Mercator.mapRenderSize(dimensions)
    expect(max(capped.width, capped.height) <= 3840 && min(capped.width, capped.height) <= 2560, "map render cap")
    near(capped.width / capped.height, dimensions.width / dimensions.height, "cap preserves aspect")
    var union = Set<TileID>()
    for time in stride(from: 0.0, through: 20000, by: 13) {
        let drift = Mercator.drift(time)
        expect(abs(drift.x) <= 160 && abs(drift.y) <= 120, "bounded movement")
        let visible = Mercator.viewport(center: CGPoint(x: 180032 + drift.x, y: 220035 + drift.y), size: capped, zoom: 14)
        union.formUnion(visible.map(\.id))
        expect(visible.count <= 176, "bounded visible tile count")
    }
    expect(union.count <= 256, "long sessions use bounded neighborhood")
}
let retina = Mercator.mapRenderSize(CGSize(width: 1920, height: 1080), backingScale: 2)
expect(retina == CGSize(width: 3840, height: 2160), "4K display uses native pixels")
let fiveK = Mercator.mapRenderSize(CGSize(width: 2560, height: 1440), backingScale: 2)
expect(fiveK == CGSize(width: 3840, height: 2160), "5K display retains 4K detail within budget")
for bearing in [0.0, 0.7, 1.8, 3.0] {
    var horizontal = false, vertical = false, left = false, right = false, up = false, down = false
    for t in stride(from: 0.0, through: 630, by: 1) {
        let p = Mercator.drift(t, bearing: bearing), q = Mercator.drift(t + 0.01, bearing: bearing)
        let dx = (q.x - p.x) / 0.01, dy = (q.y - p.y) / 0.01
        expect(hypot(dx, dy) >= 1.19 && hypot(dx, dy) <= 1.61, "camera never stalls or accelerates abruptly")
        horizontal = horizontal || abs(dx) > abs(dy) * 2; vertical = vertical || abs(dy) > abs(dx) * 2
        left = left || dx < -0.5; right = right || dx > 0.5; up = up || dy > 0.5; down = down || dy < -0.5
    }
    expect(horizontal && vertical && left && right && up && down, "route varies direction in every city")
}
expect((50...100).contains(MapCity.all.count), "curated catalog size")
expect(Set(MapCity.all.map(\.name)).count == MapCity.all.count, "unique cities")
expect(MapCity.all.allSatisfy { abs($0.latitude) <= 85 && abs($0.longitude) <= 180 && (12...15).contains($0.zoom) }, "valid city coordinates")
let recent = Array(MapCity.all.prefix(8).map(\.name))
expect(!recent.contains(MapCity.choose(recent: recent, randomIndex: { _ in 0 }).name), "recent cities avoided")

// Session restart selects a new public city even when macOS reuses a view instance.
let restarted = CityDriftScene(store: b, networkEnabled: false)
restarted.start(); let initialCity = restarted.city; restarted.stop(); restarted.start()
expect(restarted.city != initialCity, "reused view avoids previous session city")
restarted.stop()
let fixedScene = CityDriftScene(store: b, networkEnabled: false, city: MapCity.all[0])
fixedScene.start(); fixedScene.stop(); fixedScene.start()
expect(fixedScene.city == MapCity.all[0], "explicit preview city stays fixed")
fixedScene.stop()

// Simulate twelve minutes without rendering or live network; include slow/paused camera.
let touring = CityDriftScene(store: b, networkEnabled: false)
var paused = SaverSettings(); paused.speed = 0; touring.apply(paused); touring.start()
var visited = [touring.city.name]
for frame in 0...2884 {
    touring.advance(time: Double(frame) / 4)
    if touring.city.name != visited.last { visited.append(touring.city.name) }
}
expect(visited.count == 3 && Set(visited).count == 3, "automatic city changes without restart or camera motion")
touring.stop(); let stoppedCity = touring.city
touring.advance(time: 90000)
expect(touring.city == stoppedCity, "stopped saver does not tour")
fixedScene.start()
for frame in 0...2000 { fixedScene.advance(time: Double(frame) / 4) }
expect(fixedScene.city == MapCity.all[0], "explicit preview city does not auto-cycle")
fixedScene.stop()
let delayed = CityDriftScene(store: b, networkEnabled: false)
delayed.start(); let delayedCity = delayed.city
delayed.advance(time: 0); delayed.advance(time: 240.75)
expect(delayed.city == delayedCity, "outgoing city remains until the transition deadline")
delayed.advance(time: 241.5)
expect(delayed.city != delayedCity, "city deadline follows elapsed time rather than frame count")
delayed.stop()

// The real layer renderer consumes backing pixels, retaining 256-pixel tile detail.
let crisp = CityDriftScene(store: b, networkEnabled: false, city: MapCity.all[0])
crisp.useFixture(TileCache.decode(tilePNG())!); crisp.start()
let root = CALayer(); root.contentsScale = 2
let logical = CGSize(width: 2560, height: 1440)
root.bounds = CGRect(origin: .zero, size: logical)
CATransaction.begin(); CATransaction.setDisableActions(true)
expect(crisp.updateLayer(root, size: logical, time: 0, date: fixed), "Retina map layer render")
_ = crisp.updateLayer(root, size: logical, time: 2, date: fixed)
let mapLayers = root.sublayers![1].sublayers!
expect(!mapLayers.isEmpty && mapLayers.count <= 176, "bounded Retina tile layers")
expect(mapLayers.allSatisfy { ($0.contents as! CGImage).width == 256 && $0.opacity == 1 }, "native tile detail and completed fade")
expect((root.sublayers![2].contents as! CGImage).width == 3840, "Retina overlay raster matches high detail viewport")
root.contentsScale = 1
_ = crisp.updateLayer(root, size: logical, time: 3, date: fixed)
expect((root.sublayers![2].contents as! CGImage).width == 2560, "backing scale change rebuilds overlay")
CATransaction.commit(); crisp.stop()

// Dark styles preserve solid strokes and antialiasing instead of extracting their outlines.
let glyph = bitmap(width: 256, height: 256)!
glyph.setFillColor(NSColor.white.cgColor); glyph.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
glyph.setFillColor(NSColor.black.cgColor); glyph.fill(CGRect(x: 64, y: 64, width: 128, height: 128))
for palette in [MapPalette.blueprint, .night, .terminal] {
    let scene = CityDriftScene(store: b, networkEnabled: false, city: MapCity.all[0])
    scene.useFixture(glyph.makeImage()!); scene.start()
    var settings = SaverSettings(); settings.palette = palette; settings.intensity = 1; settings.speed = 0
    scene.apply(settings)
    let layer = CALayer(); layer.contentsScale = 2
    CATransaction.begin(); CATransaction.setDisableActions(true)
    _ = scene.updateLayer(layer, size: CGSize(width: 300, height: 200), time: 0, date: fixed)
    let rep = NSBitmapImageRep(cgImage: layer.sublayers![1].sublayers![0].contents as! CGImage)
    let center = rep.colorAt(x: 128, y: 128)!.usingColorSpace(.sRGB)!
    let outside = rep.colorAt(x: 16, y: 16)!.usingColorSpace(.sRGB)!
    expect(center.redComponent + center.greenComponent + center.blueComponent > outside.redComponent + outside.greenComponent + outside.blueComponent + 0.8, "\(palette): filled lettering stays filled, not hollow outlines")
    CATransaction.commit(); scene.stop()
}

// Cutting one image into tiles must not alter its tone, including pixels at the cuts.
let toneSource = bitmap(width: 512, height: 512)!
for x in 0..<512 {
    toneSource.setFillColor(NSColor(white: CGFloat(x % 256) / 255, alpha: 1).cgColor)
    toneSource.fill(CGRect(x: x, y: 0, width: 1, height: 512))
}
line(toneSource, from: CGPoint(x: 0, y: 17), to: CGPoint(x: 512, y: 489), width: 3.5, color: NSColor.black.cgColor)
let unstyled = Array(UnsafeBufferPointer(start: toneSource.data!.assumingMemoryBound(to: UInt8.self), count: toneSource.bytesPerRow * 512))
let tintBackground = RGB(0.065, 0.16, 0.25), tintInk = RGB(0.68, 0.85, 0.89)
DarkMapTint.apply(to: toneSource, background: tintBackground, ink: tintInk, intensity: 0.85)
let whole = toneSource.data!.assumingMemoryBound(to: UInt8.self)
var identicalCuts = true
for tileY in 0..<2 {
    for tileX in 0..<2 {
        let piece = bitmap(width: 256, height: 256)!
        unstyled.withUnsafeBytes { bytes in
            for row in 0..<256 {
                piece.data!.advanced(by: row * piece.bytesPerRow).copyMemory(from: bytes.baseAddress!.advanced(by: (tileY * 256 + row) * toneSource.bytesPerRow + tileX * 256 * 4), byteCount: 256 * 4)
            }
        }
        DarkMapTint.apply(to: piece, background: tintBackground, ink: tintInk, intensity: 0.85)
        let pixels = piece.data!.assumingMemoryBound(to: UInt8.self)
        for row in 0..<256 {
            for byte in 0..<(256 * 4) {
                identicalCuts = identicalCuts && pixels[row * piece.bytesPerRow + byte] == whole[(tileY * 256 + row) * toneSource.bytesPerRow + tileX * 256 * 4 + byte]
            }
        }
    }
}
expect(identicalCuts, "dark tint is pixel-identical across tile cuts, including antialiased lines")

// Actual layer composition: flat map areas must stay flat across the tile grid at
// Retina and non-integer scales, after loading and while moving subpixel distances.
let flat = bitmap(width: 256, height: 256)!
flat.setFillColor(NSColor(white: 0.8, alpha: 1).cgColor); flat.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
for palette in MapPalette.allCases {
    for scale in [CGFloat(1), 1.5, 2] {
        let scene = CityDriftScene(store: b, networkEnabled: false, city: MapCity.all[0])
        scene.useFixture(flat.makeImage()!); scene.start()
        var settings = SaverSettings(); settings.palette = palette; settings.labels = false; settings.vignette = false
        scene.apply(settings)
        let size = CGSize(width: 641, height: 385)
        let layer = CALayer(); layer.bounds = CGRect(origin: .zero, size: size); layer.contentsScale = scale
        CATransaction.begin(); CATransaction.setDisableActions(true)
        _ = scene.updateLayer(layer, size: size, time: 0, date: fixed)
        _ = scene.updateLayer(layer, size: size, time: 2, date: fixed)
        _ = scene.updateLayer(layer, size: size, time: 2.033, date: fixed)
        let frame = bitmap(width: Int(size.width * scale), height: Int(size.height * scale))!
        frame.scaleBy(x: scale, y: scale); layer.render(in: frame)
        let pixels = frame.data!.assumingMemoryBound(to: UInt8.self)
        var low = [255, 255, 255], high = [0, 0, 0]
        // Exclude the fixed attribution plaque and the viewport's entering edge tiles.
        for y in (frame.height / 3)..<(frame.height * 2 / 3) {
            for x in 32..<(frame.width - 32) {
                for channel in 0..<3 {
                    let value = Int(pixels[y * frame.bytesPerRow + x * 4 + channel])
                    low[channel] = min(low[channel], value); high[channel] = max(high[channel], value)
                }
            }
        }
        expect(zip(low, high).allSatisfy { $1 - $0 <= 2 }, "\(palette) at \(scale)x: no persistent tile grid (\(low)...\(high))")
        CATransaction.commit(); scene.stop()
    }
}

// HTTP cache semantics and invalid data.
let now = Date(timeIntervalSince1970: 1700000000), png = tilePNG()
let fallback = CachePolicy.entry(data: png, response: response(), now: now)!
near(fallback.expires.timeIntervalSince(now), 7 * 86400, "seven-day fallback")
let fresh = CachePolicy.entry(data: png, response: response(200, ["Cache-Control": "public, max-age=3600", "Age": "100", "ETag": "abc"]), now: now)!
near(fresh.expires.timeIntervalSince(now), 3500, "honor max-age and Age")
expect(fresh.etag == "abc", "ETag retained")
let inherited = CachePolicy.entry(data: png, response: response(304), now: now, previous: fresh)!
near(inherited.expires.timeIntervalSince(now), 3600, "304 inherits stored Cache-Control")
expect(inherited.etag == "abc", "304 inherits validator")
expect(CachePolicy.entry(data: png, response: response(), now: now, previous: fresh)!.etag == nil, "new 200 discards old validator")
let revalidate = CachePolicy.entry(data: png, response: response(200, ["Cache-Control": "no-cache"]), now: now)!
expect(CachePolicy.entry(data: png, response: response(304), now: now, previous: revalidate)!.expires == now, "304 preserves no-cache policy")
expect(CachePolicy.entry(data: png, response: response(200, ["Cache-Control": "no-store"]), now: now) == nil, "honor no-store")
expect(CachePolicy.entry(data: png, response: response(200, ["Cache-Control": "no-cache"]), now: now)!.expires == now, "no-cache revalidates")
let dated = CachePolicy.entry(data: png, response: response(200, ["Date": "Tue, 14 Nov 2023 22:13:20 GMT", "Expires": "Tue, 14 Nov 2023 23:13:20 GMT"]), now: now)!
near(dated.expires.timeIntervalSince(now), 3600, "Expires parsing")
expect(TileCache.decode(Data("not a PNG".utf8)) == nil && TileCache.decode(png) != nil, "validate decoded tile")
let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: temp) }
let cache = TileCache(directory: temp)
cache.write(fresh, id: tile); expect(cache.read(tile)?.data == png, "atomic disk cache roundtrip")
try! Data("broken".utf8).write(to: temp.appendingPathComponent(tile.key + ".json"))
expect(cache.read(tile) == nil, "corrupt cache recovers")

// Bundled maps cover fresh installs without contacting any tile server.
let starterMaps = StarterMaps.load(url: URL(fileURLWithPath: "Assets/StarterMaps/streets.json"))
expect(Set(starterMaps.catalog.map(\.name)) == Set(["Paris", "Boston", "Tokyo"]), "three bundled starter cities")
expect(starterMaps.cities.allSatisfy { $0.extent >= 2080 && !$0.roads.isEmpty && !$0.sourceDate.isEmpty }, "starter data covers capped viewport plus motion")
expect(starterMaps.cities.allSatisfy { $0.roads.allSatisfy { $0.points.count >= 2 && $0.points.allSatisfy { $0.count == 2 && $0.allSatisfy(\.isFinite) } } }, "valid starter geometry")
let paris = MapCity.all.first { $0.name == "Paris" }!
let smallViewport = CGSize(width: 641, height: 385)
let visitTiles = CityVisitCache.initialTiles(city: paris, viewport: smallViewport)
let visitDisk = TileCache(directory: temp.appendingPathComponent("city-visits"))
let usable = CachePolicy.entry(data: png, response: response(200, ["Cache-Control": "max-age=3600"]), now: Date())!
for id in visitTiles { visitDisk.write(usable, id: id) }
let visitCache = CityVisitCache(cache: visitDisk)
var visitDone = false, cachedVisit: CachedCityVisit?
visitCache.prepare(candidates: [MapCity.all[0], paris], viewport: smallViewport) { cachedVisit = $0; visitDone = true }
waitUntil { visitDone }
expect(cachedVisit?.city == paris && cachedVisit?.images.count == visitTiles.count, "startup may reuse any complete cached city")
var forbiddenStale = usable; forbiddenStale.expires = .distantPast; forbiddenStale.mustRevalidate = true
visitDisk.write(forbiddenStale, id: visitTiles[0]); visitDone = false; cachedVisit = nil
visitCache.prepare(candidates: [paris], viewport: smallViewport) { cachedVisit = $0; visitDone = true }
waitUntil { visitDone }
expect(visitDone && cachedVisit == nil, "preloading never bypasses mandatory revalidation")
visitDisk.write(usable, id: visitTiles[0])
try! Data("broken".utf8).write(to: visitDisk.directory.appendingPathComponent(visitTiles[0].key + ".json"))
visitDone = false
visitCache.prepare(candidates: [paris], viewport: smallViewport) { cachedVisit = $0; visitDone = true }
waitUntil { visitDone }
expect(visitDone && cachedVisit == nil, "corrupt cached city is not presented as complete")
visitDisk.write(usable, id: visitTiles[0])

let cachedStart = CityDriftScene(store: b, networkEnabled: false, starterMaps: starterMaps, visitCache: visitCache)
let startupRoot = CALayer(); startupRoot.bounds = CGRect(origin: .zero, size: smallViewport)
cachedStart.start()
CATransaction.begin(); CATransaction.setDisableActions(true)
_ = cachedStart.updateLayer(startupRoot, size: smallViewport, time: 0, date: fixed)
expect(!(startupRoot.sublayers![0].sublayers ?? []).isEmpty, "fresh startup immediately displays bundled vector streets")
waitUntil {
    _ = cachedStart.updateLayer(startupRoot, size: smallViewport, time: 0.01, date: fixed)
    return cachedStart.city == paris && !(startupRoot.sublayers![1].sublayers ?? []).isEmpty
}
expect(cachedStart.city == paris && !(startupRoot.sublayers![1].sublayers ?? []).isEmpty, "cached startup replaces initial map without network")
CATransaction.commit(); cachedStart.stop()

// Queued cache reads must not change a stopped or resized scene.
let onlyTokyo = StarterMaps(cities: starterMaps.cities.filter { $0.name == "Tokyo" })
let cancelledStartup = CityDriftScene(store: b, networkEnabled: false, starterMaps: onlyTokyo, visitCache: visitCache)
let cancelledRoot = CALayer(); cancelledRoot.bounds = CGRect(origin: .zero, size: smallViewport)
cancelledStartup.start()
_ = cancelledStartup.updateLayer(cancelledRoot, size: smallViewport, time: 0, date: fixed)
cancelledStartup.stop()
var drained = false
visitCache.prepare(candidates: [], viewport: smallViewport) { _ in drained = true }
waitUntil { drained }
expect(cancelledStartup.city.name == "Tokyo", "stopped scene rejects queued startup-cache selection")
let resizedStartup = CityDriftScene(store: b, networkEnabled: false, starterMaps: onlyTokyo, visitCache: visitCache)
resizedStartup.start()
_ = resizedStartup.updateLayer(cancelledRoot, size: smallViewport, time: 0, date: fixed)
_ = resizedStartup.updateLayer(cancelledRoot, size: CGSize(width: 1000, height: 800), time: 0.01, date: fixed)
drained = false
visitCache.prepare(candidates: [], viewport: smallViewport) { _ in drained = true }
waitUntil { drained }
expect(resizedStartup.city.name == "Tokyo", "resize rejects a cached city that only covered the old viewport")
resizedStartup.stop()

// Crossfade the complete outgoing scene instead of fading to an empty tile grid.
let crossfade = CityDriftScene(store: b, networkEnabled: false, starterMaps: .empty)
crossfade.useFixture(flat.makeImage()!); crossfade.start()
let transitionRoot = CALayer(); transitionRoot.bounds = CGRect(origin: .zero, size: smallViewport)
CATransaction.begin(); CATransaction.setDisableActions(true)
_ = crossfade.updateLayer(transitionRoot, size: smallViewport, time: 0, date: fixed)
_ = crossfade.updateLayer(transitionRoot, size: smallViewport, time: 2, date: fixed)
let outgoing = crossfade.city
_ = crossfade.updateLayer(transitionRoot, size: smallViewport, time: 241.5, date: fixed)
expect(crossfade.city != outgoing && transitionRoot.sublayers?.count == 4 && transitionRoot.sublayers?.last?.opacity == 1, "outgoing scene remains opaque until incoming scene is ready")
_ = crossfade.updateLayer(transitionRoot, size: smallViewport, time: 243, date: fixed)
expect(transitionRoot.sublayers?.count == 3, "completed crossfade releases outgoing map memory")
CATransaction.commit(); crossfade.stop()

let offlineTour = CityDriftScene(store: b, networkEnabled: false, starterMaps: starterMaps)
let offlineRoot = CALayer(); offlineRoot.bounds = CGRect(origin: .zero, size: smallViewport)
offlineTour.start()
CATransaction.begin(); CATransaction.setDisableActions(true)
_ = offlineTour.updateLayer(offlineRoot, size: smallViewport, time: 0, date: fixed)
_ = offlineTour.updateLayer(offlineRoot, size: smallViewport, time: 241.5, date: fixed)
_ = offlineTour.updateLayer(offlineRoot, size: smallViewport, time: 263, date: fixed)
_ = offlineTour.updateLayer(offlineRoot, size: smallViewport, time: 265, date: fixed)
expect(starterMaps[offlineTour.city] != nil && offlineRoot.sublayers?.count == 3, "unavailable city falls back to a moving bundled map, not a frozen cover")
CATransaction.commit(); offlineTour.stop()

// Mocked network integration: concurrency, validators, 304, offline, cancellation, throttling.
let first = TileID(z: 2, x: 0, y: 0)!, second = TileID(z: 2, x: 1, y: 0)!, third = TileID(z: 2, x: 2, y: 0)!
var expired = fresh; expired.expires = .distantPast; expired.mustRevalidate = true
cache.write(expired, id: first)
let transport = MockTransport(); var received = Set<TileID>()
let loader = TileLoader(cache: cache, transport: transport) { id, _ in received.insert(id) }
loader.request([first, second, third]); waitUntil { transport.calls.count == 2 }
expect(transport.calls.count == 2, "two-request concurrency limit")
let calls = transport.calls
expect(calls[0].request.value(forHTTPHeaderField: "If-None-Match") == "abc", "conditional ETag request")
expect(calls[0].request.value(forHTTPHeaderField: "User-Agent")?.contains("ScreensaversForMac/") == true, "identifying user agent")
expect(calls.allSatisfy { $0.request.value(forHTTPHeaderField: "Cache-Control") == nil }, "never bypass caching")
calls[0].completion(nil, response(304, ["Cache-Control": "max-age=3600"]), nil)
waitUntil { transport.calls.count == 3 && received.contains(first) }
expect(received.contains(first), "304 serves cached body")
expect(cache.read(first)!.expires > Date(), "304 refreshes cache metadata")
loader.stop(); waitUntil { transport.calls[1].token.cancelled }
expect(transport.calls[1].token.cancelled && transport.calls[2].token.cancelled, "stop cancels in-flight requests")
let count = received.count
transport.calls[1].completion(png, response(200, ["Content-Type": "image/png"]), nil)
RunLoop.main.run(until: Date().addingTimeInterval(0.05)); expect(received.count == count, "no post-stop network delivery")
let offline = MockTransport(); var fallbackCount = 0
expired.mustRevalidate = false; cache.write(expired, id: second)
let offlineLoader = TileLoader(cache: cache, transport: offline) { _, _ in fallbackCount += 1 }
offlineLoader.request([second]); waitUntil { offline.calls.count == 1 && fallbackCount == 1 }
offline.calls[0].completion(nil, nil, URLError(.notConnectedToInternet))
expect(fallbackCount == 1, "offline stale fallback")
offlineLoader.stop()
let limited = MockTransport()
let limitedLoader = TileLoader(cache: TileCache(directory: temp.appendingPathComponent("limited")), transport: limited) { _, _ in }
limitedLoader.request([first, second, third]); waitUntil { limited.calls.count == 2 }
limited.calls[0].completion(nil, response(429, ["Retry-After": "120"]), nil)
limited.calls[1].completion(nil, response(500), nil)
RunLoop.main.run(until: Date().addingTimeInterval(0.05))
expect(limited.calls.count == 2, "429 clears pending queue and backs off")
limitedLoader.beginVisit()
limitedLoader.request([third]); RunLoop.main.run(until: Date().addingTimeInterval(0.05))
expect(limited.calls.count == 2, "server backoff survives city change")
limitedLoader.stop()
let budgetTransport = MockTransport()
let budgetLoader = TileLoader(cache: TileCache(directory: temp.appendingPathComponent("budget")), transport: budgetTransport) { _, _ in }
let many = (0..<280).map { TileID(z: 8, x: $0 % 256, y: $0 / 256)! }
budgetLoader.request(many)
var finished = 0
waitUntil({
    let current = budgetTransport.calls
    while finished < current.count {
        current[finished].completion(nil, response(404), nil)
        finished += 1
    }
    return finished == 256
}, timeout: 15)
RunLoop.main.run(until: Date().addingTimeInterval(0.05))
expect(budgetTransport.calls.count == 256, "hard city budget under repeated failures (received \(budgetTransport.calls.count), completed \(finished))")
budgetLoader.beginVisit(); budgetLoader.request([first, second])
waitUntil { budgetTransport.calls.count == 258 }
expect(budgetTransport.calls.count == 258, "new city resets the bounded request allowance")
budgetLoader.stop()
let visitsTransport = MockTransport(); var visitsDelivered = 0
let visitsLoader = TileLoader(cache: TileCache(directory: temp.appendingPathComponent("visits")), transport: visitsTransport) { _, _ in visitsDelivered += 1 }
visitsLoader.request([first]); waitUntil { visitsTransport.calls.count == 1 }
let abandoned = visitsTransport.calls[0]
visitsLoader.beginVisit(); visitsLoader.request([first, second, third])
waitUntil { visitsTransport.calls.count == 3 }
expect(abandoned.token.cancelled, "city change cancels previous tile tasks")
abandoned.completion(png, response(200, ["Content-Type": "image/png"]), nil)
RunLoop.main.run(until: Date().addingTimeInterval(0.05))
expect(visitsDelivered == 0 && visitsTransport.calls.count == 3, "late old-city response cannot deliver or free a new request slot")
visitsLoader.stop()
let cachedTransport = MockTransport(); var cachedDelivered = false
cache.write(CachePolicy.entry(data: png, response: response(200, ["Cache-Control": "max-age=3600"]), now: Date()), id: third)
let cachedLoader = TileLoader(cache: cache, transport: cachedTransport) { _, _ in cachedDelivered = true }
cachedLoader.request([third]); waitUntil { cachedDelivered }
expect(cachedDelivered && cachedTransport.calls.isEmpty, "fresh cache requires no network")
cachedLoader.request([])
cachedLoader.request([third]); cachedDelivered = false; waitUntil { cachedDelivered }
expect(cachedDelivered && cachedTransport.calls.isEmpty, "revisited tile returns from cache after leaving viewport")
cachedLoader.stop()
print("\(checks) checks, \(failures) failures (no live network requests).")
exit(failures == 0 ? 0 : 1)
