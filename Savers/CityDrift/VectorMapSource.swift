import Foundation
import CoreGraphics

struct CachedVectorVisit {
    let city: MapCity
    let viewport: CGSize
    let tiles: [TileID: VectorTile]
    let usableUntil: Date
    var isUsable: Bool { Date() < usableUntil }
}

/// The network source retains only current-viewport geometry. Scene selection and
/// disk-only warming are separate from network requests for the displayed city.
final class VectorMapSource {
    static let provider = TileProvider(template: "https://vector.openstreetmap.org/shortbread_v1/{z}/{x}/{y}.mvt",
                                       cacheNamespace: "osm-shortbread-v1", attribution: "© OpenStreetMap contributors")
    static func makeCache(directory: URL? = nil) -> TileCache {
        TileCache(directory: directory, namespace: provider.cacheNamespace, maximumRecordBytes: 3_000_000,
                  validate: { VectorTile.decode($0) != nil })
    }
    private let cache: TileCache
    private let transport: TileTransport?
    private let networkEnabled: Bool
    private let cacheQueue = DispatchQueue(label: "screensavers.vector-visits", qos: .utility)
    private var loader: TileResourceLoader<VectorTile>?
    private var tiles: [TileID: VectorTile] = [:]
    private var visible: [TilePlacement] = []
    private var city: MapCity?
    private var dirty = false
    private var generation = 0
    private(set) var map: StarterMap?
    private(set) var revision = 0
    var complete: Bool { !visible.isEmpty && visible.allSatisfy { tiles[$0.id] != nil } }
    init(networkEnabled: Bool, cache: TileCache? = nil, transport: TileTransport? = nil) {
        self.networkEnabled = networkEnabled; self.cache = cache ?? Self.makeCache(); self.transport = transport
    }
    func begin(city: MapCity, preloaded: [TileID: VectorTile] = [:]) {
        self.city = city; tiles = preloaded; visible = []; map = nil; revision += 1; dirty = true
        loader?.beginVisit()
        if loader == nil {
            let session = generation
            loader = TileResourceLoader(provider: Self.provider, cache: cache,
                                        transport: networkEnabled ? (transport ?? HTTPTransport(maximumBytes: VectorTile.maximumBytes)) : CacheOnlyTransport(),
                                        mimeTypes: ["application/vnd.mapbox-vector-tile", "application/x-protobuf", "application/octet-stream"],
                                        decode: VectorTile.decode) { [weak self] id, tile in
                guard let self, self.generation == session, self.visible.contains(where: { $0.id == id }) else { return }
                self.tiles[id] = tile; self.dirty = true
            }
        }
    }
    func stop() { generation += 1; loader?.stop(); loader = nil; tiles = [:]; map = nil; visible = []; revision += 1 }
    func update(_ placements: [TilePlacement]) {
        if visible != placements {
            visible = placements
            let ids = Set(placements.map(\.id)); tiles = tiles.filter { ids.contains($0.key) }
            loader?.request(placements.map(\.id)); dirty = true
        }
        // Replace a complete map as a unit. Never render partly arrived vector tiles.
        if dirty && complete, let city {
            map = Self.compose(city: city, placements: visible, tiles: tiles)
            dirty = false; revision += 1
        }
    }
    @discardableResult
    func prepare(candidates: [MapCity], viewport: CGSize, completion: @escaping (CachedVectorVisit?) -> Void) -> CityCacheRead {
        let read = CityCacheRead()
        cacheQueue.async { [cache] in
            let files = Set((try? FileManager.default.contentsOfDirectory(atPath: cache.directory.path)) ?? [])
            var result: CachedVectorVisit?
            for city in candidates {
                guard !read.isCancelled else { return }
                let ids = CityVisitCache.initialTiles(city: city, viewport: viewport)
                guard !ids.isEmpty, ids.allSatisfy({ files.contains($0.key + ".json") }) else { continue }
                var tiles: [TileID: VectorTile] = [:], expiry = Date.distantFuture
                for id in ids {
                    guard !read.isCancelled else { return }
                    guard let entry = cache.read(id), entry.expires > Date() || !entry.mustRevalidate,
                          let tile = VectorTile.decode(entry.data) else { break }
                    tiles[id] = tile
                    if entry.mustRevalidate { expiry = min(expiry, entry.expires) }
                }
                if tiles.count == ids.count { result = CachedVectorVisit(city: city, viewport: viewport, tiles: tiles, usableUntil: expiry); break }
            }
            DispatchQueue.main.async { if !read.isCancelled { completion(result) } }
        }
        return read
    }
    static func compose(city: MapCity, placements: [TilePlacement], tiles: [TileID: VectorTile]) -> StarterMap {
        let center = Mercator.point(latitude: city.latitude, longitude: city.longitude, zoom: city.zoom)
        var roads: [StarterMap.Road] = [], labels: [StarterMap.Road] = [], areas: [StarterMap.Area] = []
        var waterways: [[[Double]]] = [], places: [StarterMap.Place] = []
        let roadKinds: Set<String> = ["motorway", "trunk", "primary", "secondary", "tertiary", "residential", "unclassified", "living_street", "pedestrian", "service", "busway"]
        for placement in placements {
            guard let tile = tiles[placement.id] else { continue }
            let dx = Double(placement.x * 256) - Double(center.x), dy = Double(placement.y * 256) - Double(center.y)
            for feature in tile.features {
                let paths = feature.paths.map { $0.map { [Double($0.x) + dx, Double($0.y) + dy] } }
                switch feature.layer {
                case "streets" where feature.type == 2 && roadKinds.contains(feature.kind):
                    let kind = ["motorway", "trunk", "primary", "secondary", "tertiary"].contains(feature.kind) ? feature.kind : "minor"
                    roads += paths.map { .init(kind: kind, points: $0, name: nil) }
                case "street_labels" where feature.type == 2 && !feature.name.isEmpty:
                    labels += paths.map { .init(kind: feature.kind, points: $0, name: feature.name) }
                case let layer where ["ocean", "water_polygons"].contains(layer) && feature.type == 3:
                    areas.append(.init(kind: "water", rings: paths))
                case "water_lines" where feature.type == 2: waterways += paths
                case let layer where ["land", "sites"].contains(layer) && feature.type == 3 && ["park", "forest", "wood", "grass", "recreation_ground", "village_green", "garden"].contains(feature.kind):
                    areas.append(.init(kind: "park", rings: paths))
                case let layer where ["pois", "public_transport"].contains(layer) && feature.type == 1 && !feature.name.isEmpty:
                    for path in paths { for point in path { places.append(.init(name: feature.name, point: point)) } }
                default: break
                }
            }
        }
        return StarterMap(name: city.name, zoom: city.zoom, extent: 2304, roads: roads, sourceDate: "HTTP-cached Shortbread",
                          areas: areas, waterways: waterways, pointsOfInterest: places, streetNames: labels)
    }
}

private final class CacheOnlyTransport: TileTransport {
    private struct Cancel: TileCancellation { func cancel() {} }
    func fetch(_ request: URLRequest, completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) -> TileCancellation {
        completion(nil, nil, URLError(.notConnectedToInternet)); return Cancel()
    }
}
