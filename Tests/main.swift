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
expect(value.sanitized().speed == 1 && value.sanitized().density == 0.7 && value.sanitized().floor == SaverSettings().floor, "sanitize invalid settings")
defaultsA.set(Data("invalid".utf8), forKey: "settings.v1"); expect(a.value == SaverSettings(), "corrupt settings fallback")
a.value = value.sanitized(); a.reset(); expect(a.value == SaverSettings(), "reset defaults")

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
    let capped = Mercator.renderSize(dimensions)
    expect(capped.width <= 1792 && capped.height <= 1120, "render cap")
    near(capped.width / capped.height, dimensions.width / dimensions.height, "cap preserves aspect")
    var union = Set<TileID>()
    for time in stride(from: 0.0, through: 20000, by: 13) {
        let drift = Mercator.drift(time)
        expect(abs(drift.x) <= 80 && abs(drift.y) <= 55, "bounded movement")
        let visible = Mercator.viewport(center: CGPoint(x: 180032 + drift.x, y: 220035 + drift.y), size: capped, zoom: 14)
        union.formUnion(visible.map(\.id))
        expect(visible.count <= 48, "bounded visible tile count")
    }
    expect(union.count <= 63, "long sessions use bounded neighborhood")
}
expect((50...100).contains(MapCity.all.count), "curated catalog size")
expect(Set(MapCity.all.map(\.name)).count == MapCity.all.count, "unique cities")
expect(MapCity.all.allSatisfy { abs($0.latitude) <= 85 && abs($0.longitude) <= 180 && (12...15).contains($0.zoom) }, "valid city coordinates")
let recent = Array(MapCity.all.prefix(8).map(\.name))
expect(!recent.contains(MapCity.choose(recent: recent, randomIndex: { _ in 0 }).name), "recent cities avoided")

// HTTP cache semantics and invalid data.
let now = Date(timeIntervalSince1970: 1700000000), png = tilePNG()
let fallback = CachePolicy.entry(data: png, response: response(), now: now)!
near(fallback.expires.timeIntervalSince(now), 7 * 86400, "seven-day fallback")
let fresh = CachePolicy.entry(data: png, response: response(200, ["Cache-Control": "public, max-age=3600", "Age": "100", "ETag": "abc"]), now: now)!
near(fresh.expires.timeIntervalSince(now), 3500, "honor max-age and Age")
expect(fresh.etag == "abc", "ETag retained")
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
limitedLoader.stop()
print("\(checks) checks, \(failures) failures (no live network requests).")
exit(failures == 0 ? 0 : 1)
