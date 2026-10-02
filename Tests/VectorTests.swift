import AppKit
import Foundation

// Synthetic MVT protobufs, generated locally. Tests never request public tiles.
private func vint(_ n: UInt64) -> Data {
    var n = n, data = Data()
    repeat { let b = UInt8(n & 127); n >>= 7; data.append(b | (n == 0 ? 0 : 128)) } while n > 0
    return data
}
private func field(_ id: Int, _ n: Int) -> Data { vint(UInt64(id << 3)) + vint(UInt64(n)) }
private func message(_ id: Int, _ data: Data) -> Data { vint(UInt64(id << 3 | 2)) + vint(UInt64(data.count)) + data }
private func packed(_ ints: [Int]) -> Data { ints.reduce(Data()) { $0 + vint(UInt64($1)) } }
private func feature(_ type: Int, _ geometry: [Int], _ tags: [Int] = [0, 0, 1, 1]) -> Data {
    message(2, packed(tags)) + field(3, type) + message(4, packed(geometry))
}
private func layer(_ name: String, type: Int, kind: String, geometry: [Int], version: Int = 2) -> Data {
    message(1, Data(name.utf8)) + message(2, feature(type, geometry)) +
        message(3, Data("kind".utf8)) + message(3, Data("name".utf8)) +
        message(4, message(1, Data(kind.utf8))) + message(4, message(1, Data("Test Street".utf8))) + field(5, 4096) + field(15, version)
}
func syntheticVectorTile() -> Data {
    let road = [9, 0, 4096, 10, 8192, 0] // west-east line at half-tile
    let ring = [9, 512, 512, 26, 3072, 0, 0, 3072, 3071, 0, 15]
    return message(3, layer("streets", type: 2, kind: "residential", geometry: road)) +
        message(3, layer("street_labels", type: 2, kind: "residential", geometry: road)) +
        message(3, layer("water_polygons", type: 3, kind: "water", geometry: ring)) +
        message(3, layer("land", type: 3, kind: "park", geometry: ring)) +
        message(3, layer("pois", type: 1, kind: "museum", geometry: [9, 2048, 2048]))
}
func runVectorTests() {
    let bytes = syntheticVectorTile()
    let parsed = VectorTile.decode(bytes)
    expect(parsed?.features.count == 5, "MVT extracts all five configurable feature categories")
    expect(parsed?.features[0].paths.first == [CGPoint(x: 0, y: 128), CGPoint(x: 256, y: 128)], "MVT extent and delta geometry decode to tile pixels")
    expect(parsed?.features[2].paths.first?.first == parsed?.features[2].paths.first?.last, "MVT polygon closes its ring")
    expect(VectorTile.decode(Data()) == nil && VectorTile.decode(Data("<html>error</html>".utf8)) == nil, "empty/error responses are not vector tiles")
    expect(VectorTile.decode(Data(repeating: 255, count: 12)) == nil, "MVT overflowing varint is rejected")
    expect(VectorTile.decode(Data(repeating: 0, count: VectorTile.maximumBytes + 1)) == nil, "MVT byte limit")
    for geometry in [[0], [9], [10, 2, 2], [15], [9, 0, 0, 0x7ffffffa]] {
        expect(VectorTile.decode(message(3, layer("streets", type: 2, kind: "primary", geometry: geometry))) == nil, "MVT rejects invalid geometry commands")
    }
    expect(VectorTile.decode(message(3, layer("streets", type: 2, kind: "primary", geometry: [9, 0, 0, 10, 10, 10], version: 99))) == nil, "unsupported MVT version fails quietly")
    let truncated = message(3, layer("streets", type: 2, kind: "primary", geometry: [9, 0, 0, 10, 10, 10]))
    for n in 1..<truncated.count { expect(VectorTile.decode(truncated.prefix(n)) == nil, "truncated protobuf is rejected at byte \(n)") }
    let negative = VectorTile.decode(message(3, layer("streets", type: 2, kind: "primary", geometry: [9, 31, 31, 10, 64, 64])))
    expect(negative?.features.first?.paths.first?.first == CGPoint(x: -1, y: -1), "MVT signed coordinates retain buffered tile edges")
    let city = MapCity.all.first { $0.name == "London" }!
    let center = Mercator.point(latitude: city.latitude, longitude: city.longitude, zoom: city.zoom)
    let id = TileID(z: city.zoom, x: Int(center.x / 256), y: Int(center.y / 256))!
    let placement = TilePlacement(id: id, x: id.x, y: id.y)
    let map = VectorMapSource.compose(city: city, placements: [placement], tiles: [id: parsed!])
    expect(map.roads.count == 1 && map.roads[0].kind == "minor", "online residential roads are retained")
    expect(map.streetNames?.first?.name == "Test Street" && map.pointsOfInterest?.count == 1, "online names and POIs survive composition")
    for mask in 0..<16 {
        var options = SaverSettings(); options.streetLabels = mask & 1 != 0; options.water = mask & 2 != 0
        options.parks = mask & 4 != 0; options.pointsOfInterest = mask & 8 != 0
        let layers = map.detailLayers(settings: options, ink: .white) + map.labelLayers(settings: options, ink: .white, scale: 2)
        let names = Set(layers.compactMap(\.name))
        expect(names.contains("water") == options.water && names.contains("park") == options.parks, "online water/park controls independent (\(mask))")
        expect(names.contains("street-label") == options.streetLabels && names.contains("poi") == options.pointsOfInterest, "online street/POI controls independent (\(mask))")
    }
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temp) }
    let cache = VectorMapSource.makeCache(directory: temp)
    let transport = MockTransport()
    let source = VectorMapSource(networkEnabled: true, cache: cache, transport: transport)
    source.begin(city: city); source.update([placement]); waitUntil { transport.calls.count == 1 }
    expect(transport.calls.first?.request.url?.path.hasSuffix(".mvt") == true, "online source requests MVT, not raster imagery")
    expect(transport.calls.first?.request.value(forHTTPHeaderField: "User-Agent")?.contains("ScreensaversForMac") == true, "vector requests identify app")
    transport.calls[0].completion(bytes, response(200, ["Content-Type": "application/vnd.mapbox-vector-tile", "Cache-Control": "max-age=3600", "ETag": "v1"]), nil)
    waitUntil { source.update([placement]); return source.complete }
    expect(source.map?.roads.isEmpty == false && cache.read(id)?.data == bytes, "downloaded vectors render and persist with HTTP cache metadata")
    source.stop()
    let cachedTransport = MockTransport()
    let cached = VectorMapSource(networkEnabled: true, cache: cache, transport: cachedTransport)
    cached.begin(city: city); cached.update([placement]); waitUntil { cached.update([placement]); return cached.complete }
    expect(cached.complete && cachedTransport.calls.isEmpty, "fresh vector cache reopens without a network request")
    var details = SaverSettings(); details.streetLabels = true; details.water = true; details.parks = true; details.pointsOfInterest = true
    let previousRevision = cached.revision
    cached.configure(settings: details, ink: .blue, scale: 3); cached.update([placement])
    waitUntil { cached.update([placement]); return cached.revision > previousRevision }
    let preparedNames = Set(cached.layers.compactMap(\.name))
    expect(["road", "water", "park", "street-label", "poi"].allSatisfy { preparedNames.contains($0) }, "background preparation publishes all selected detail layers together")
    expect(cached.layers.filter { $0 is CATextLayer }.allSatisfy { $0.contentsScale == 3 }, "prepared text uses the target backing scale")
    let styledRevision = cached.revision
    details.speed = 12; cached.configure(settings: details, ink: .blue, scale: 3); cached.update([placement])
    RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    expect(cached.revision == styledRevision, "speed-only changes preserve prepared vector geometry")
    cached.stop()
    var stale = cache.read(id)!; stale.expires = .distantPast; stale.mustRevalidate = true; cache.write(stale, id: id)
    let refreshing = VectorMapSource(networkEnabled: true, cache: cache, transport: cachedTransport)
    refreshing.begin(city: city); refreshing.update([placement]); waitUntil { cachedTransport.calls.count == 1 }
    expect(!refreshing.complete && cachedTransport.calls[0].request.value(forHTTPHeaderField: "If-None-Match") == "v1", "expired vector cache honors revalidation")
    cachedTransport.calls[0].completion(nil, response(304, ["Cache-Control": "max-age=3600"]), nil)
    waitUntil { refreshing.update([placement]); return refreshing.complete }
    expect(refreshing.complete, "vector 304 reuses stored geometry")
    refreshing.stop()
    let lateTransport = MockTransport(), missing = TileID(z: 14, x: id.x + 1, y: id.y)!
    let late = VectorMapSource(networkEnabled: true, cache: cache, transport: lateTransport)
    let missingPlacement = TilePlacement(id: missing, x: missing.x, y: missing.y)
    late.begin(city: city); late.update([missingPlacement]); waitUntil { lateTransport.calls.count == 1 }
    late.stop(); waitUntil { lateTransport.calls[0].token.cancelled }
    lateTransport.calls[0].completion(bytes, response(200, ["Content-Type": "application/vnd.mapbox-vector-tile"]), nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    expect(late.map == nil && !late.complete, "stopped vector source cancels and rejects late replies")
    let viewport = CGSize(width: 256, height: 200)
    let ids = CityVisitCache.initialTiles(city: city, viewport: viewport)
    let freshEntry = CachePolicy.entry(data: bytes, response: response(200, ["Cache-Control": "max-age=3600"]), now: Date())!
    for tile in ids { cache.write(freshEntry, id: tile) }
    var selected: CachedVectorVisit?, selectionDone = false
    let cacheReader = VectorMapSource(networkEnabled: false, cache: cache)
    cacheReader.prepare(candidates: [MapCity.all[0], city], viewport: viewport) { selected = $0; selectionDone = true }
    waitUntil { selectionDone }
    expect(selected?.city == city && selected?.tiles.count == ids.count, "vector startup can select any complete cached city")
    var invalidated = freshEntry; invalidated.expires = .distantPast; invalidated.mustRevalidate = true
    cache.write(invalidated, id: ids[0]); selectionDone = false
    cacheReader.prepare(candidates: [city], viewport: viewport) { selected = $0; selectionDone = true }
    waitUntil { selectionDone }
    expect(selectionDone && selected == nil, "vector preload rejects required stale revalidation")
    try! Data("corrupt".utf8).write(to: cache.directory.appendingPathComponent(ids[0].key + ".json"))
    selectionDone = false
    cacheReader.prepare(candidates: [city], viewport: viewport) { selected = $0; selectionDone = true }
    waitUntil { selectionDone }
    expect(selectionDone && selected == nil, "vector preload rejects corrupt records")
    var cancelledDelivered = false
    let cancelled = cacheReader.prepare(candidates: [city], viewport: viewport) { _ in cancelledDelivered = true }
    cancelled.cancel()
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    expect(!cancelledDelivered, "cancelled vector cache scans cannot select a city")
    // The actual scene must select the full catalog online while keeping fallback
    // geometry visible. No live transport is used here.
    // Composition must not publish old city/viewport geometry after lifecycle changes.
    let composing = VectorMapSource(networkEnabled: false, cache: cache)
    composing.begin(city: city, preloaded: [id: parsed!]); composing.update([placement])
    expect(composing.map == nil, "vector composition is deferred off the animation thread")
    composing.stop()
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    expect(composing.map == nil && composing.paths.isEmpty, "stopped source rejects queued geometry")
    composing.begin(city: city, preloaded: [id: parsed!]); composing.update([placement])
    let replacement = MapCity.all.first { $0.name == "Paris" }!
    composing.begin(city: replacement, preloaded: [id: parsed!]); composing.update([placement])
    waitUntil { composing.update([placement]); return composing.complete }
    expect(composing.map?.name == replacement.name && !composing.paths.isEmpty, "replacement visit publishes only its own prepared paths")
    composing.update([missingPlacement])
    expect(composing.map?.name == replacement.name && !composing.complete, "incomplete viewport keeps previous complete geometry")
    composing.stop()

    let defaultsName = "screensavers.vector-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: defaultsName)!
    defer { defaults.removePersistentDomain(forName: defaultsName) }
    let store = SettingsStore(.cityDrift, defaults: defaults)
    let legacy = Data(#"{"mapStyle":"lines","speed":7,"palette":"blueprint"}"#.utf8)
    defaults.set(legacy, forKey: "settings.v2")
    expect(store.value.mapStyle == .online && store.value.speed == 7 && store.value.palette == .blueprint, "upgrade previous default to online and preserve appearance")
    var offline = store.value; offline.mapStyle = .lines; store.value = offline
    expect(store.value.mapStyle == .lines, "explicit offline selection remains offline on subsequent reads")
    store.reset()
    defaults.set(["Paris", "Boston", "Tokyo"], forKey: "recentCities")
    let starters = StarterMaps.load(url: URL(fileURLWithPath: "Assets/StarterMaps/streets.json"))
    let sceneTransport = MockTransport()
    let scene = CityDriftScene(store: store, starterMaps: starters, vectorCache: VectorMapSource.makeCache(directory: temp.appendingPathComponent("scene")), vectorTransport: sceneTransport)
    let root = CALayer(); root.contentsScale = 2
    let size = CGSize(width: 2560, height: 1440)
    expect(!["Paris", "Boston", "Tokyo"].contains(scene.city.name), "cold online startup selects a fresh worldwide destination")
    scene.start(); _ = scene.updateLayer(root, size: size, time: 0, date: Date())
    expect(!(root.sublayers![0].sublayers ?? []).isEmpty, "online default starts with complete bundled streets")
    waitUntil { _ = scene.updateLayer(root, size: size, time: 0.01, date: Date()); return sceneTransport.calls.count == 2 }
    expect(sceneTransport.calls.count == 2, "online default fetches vectors with bounded concurrency")
    let sceneViewport = Mercator.vectorRenderSize(size)
    expect(sceneViewport.width == 1920 && CityVisitCache.initialTiles(city: scene.city, viewport: sceneViewport).count <= 54, "Retina vector viewport bounds tile requests without raster upscaling")
    expect((root.sublayers![2].contents as! CGImage).width == 3840, "vector map overlay remains Retina-sharp despite smaller geographic viewport")
    let firstPosition = root.sublayers![1].position
    let fallbackPosition = root.sublayers![0].position
    _ = scene.updateLayer(root, size: size, time: 10, date: Date())
    expect(root.sublayers![1].position == firstPosition, "cold vector camera holds its initial viewport until complete, so startup cache can be reused")
    expect(root.sublayers![0].position != fallbackPosition, "bundled fallback keeps moving while the network is unavailable")
    let firstCity = scene.city
    _ = scene.updateLayer(root, size: size, time: 242, date: Date())
    expect(scene.city != firstCity, "online scene tours the full city catalog")
    scene.apply(offline)
    let countBefore = sceneTransport.calls.count
    _ = scene.updateLayer(root, size: size, time: 245, date: Date())
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    expect(sceneTransport.calls.count == countBefore && starters[scene.city] != nil, "switching to offline cancels online loading and selects bundled city")
    scene.stop()
    // A small warm cache must not monopolize every short online session.
    for tile in ids { cache.write(freshEntry, id: tile) }
    defaults.set([city.name], forKey: "recentCities")
    let variedTransport = MockTransport()
    let varied = CityDriftScene(store: store, starterMaps: starters, vectorCache: cache, vectorTransport: variedTransport)
    varied.start(); let variedRoot = CALayer()
    waitUntil {
        _ = varied.updateLayer(variedRoot, size: viewport, time: 0, date: Date())
        return !variedTransport.calls.isEmpty
    }
    expect(varied.city != city && !variedTransport.calls.isEmpty, "recent cached city does not prevent a fresh selected destination from loading")
    expect(!(variedRoot.sublayers?.first?.sublayers ?? []).isEmpty, "fresh worldwide destination retains complete bundled cover")
    varied.stop()
    let noResourcesTransport = MockTransport()
    let noResources = CityDriftScene(store: store, starterMaps: .empty, tileTransport: noResourcesTransport, vectorTransport: noResourcesTransport)
    noResources.apply(offline); noResources.start()
    _ = noResources.updateLayer(CALayer(), size: size, time: 0, date: Date())
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    expect(noResourcesTransport.calls.isEmpty, "explicit offline mode never downloads, even if bundled resources are missing")
    noResources.stop()
}
