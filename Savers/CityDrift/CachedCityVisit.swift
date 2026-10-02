import Foundation
import CoreGraphics

struct CachedCityVisit {
    let city: MapCity
    let viewport: CGSize
    let images: [TileID: CGImage]
    let usableUntil: Date
    var isUsable: Bool { Date() < usableUntil }
}

final class CityCacheRead {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}

/// Reads existing HTTP cache records only. Never creates a transport or fetches
/// future scenes from the network. Work is serialized off the animation thread.
final class CityVisitCache {
    private let queue = DispatchQueue(label: "screensavers.cached-visits", qos: .utility)
    private let cache: TileCache
    init(cache: TileCache = TileCache()) { self.cache = cache }

    static func initialTiles(city: MapCity, viewport: CGSize) -> [TileID] {
        let point = Mercator.point(latitude: city.latitude, longitude: city.longitude, zoom: city.zoom)
        let drift = Mercator.drift(0, bearing: city.longitude * .pi / 180)
        return Mercator.viewport(center: CGPoint(x: point.x + drift.x, y: point.y + drift.y), size: viewport, zoom: city.zoom).map(\.id)
    }
    @discardableResult
    func prepare(candidates: [MapCity], viewport: CGSize, completion: @escaping (CachedCityVisit?) -> Void) -> CityCacheRead {
        let read = CityCacheRead()
        queue.async { [cache] in
            guard !read.isCancelled else { return }
            // Check filenames before decoding: a cold cache should be a cheap miss,
            // even with a large catalog. Corrupt/expired records are checked below.
            let files = Set((try? FileManager.default.contentsOfDirectory(atPath: cache.directory.path)) ?? [])
            var result: CachedCityVisit?
            for city in candidates {
                guard !read.isCancelled else { return }
                let ids = Self.initialTiles(city: city, viewport: viewport)
                guard !ids.isEmpty, ids.allSatisfy({ files.contains($0.key + ".json") }) else { continue }
                var images: [TileID: CGImage] = [:]
                var usableUntil = Date.distantFuture
                for id in ids {
                    guard !read.isCancelled else { return }
                    guard let entry = cache.read(id), entry.expires > Date() || !entry.mustRevalidate,
                          let image = TileCache.decode(entry.data) else { break }
                    images[id] = image
                    if entry.mustRevalidate { usableUntil = min(usableUntil, entry.expires) }
                }
                if images.count == ids.count {
                    result = CachedCityVisit(city: city, viewport: viewport, images: images, usableUntil: usableUntil); break
                }
            }
            DispatchQueue.main.async { if !read.isCancelled { completion(result) } }
        }
        return read
    }
}
