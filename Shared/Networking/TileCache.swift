import Foundation
import ImageIO

struct CachedTile: Codable {
    var data: Data
    var stored: Date
    var expires: Date
    var etag: String?
    var modified: String?
    var mustRevalidate: Bool
}

enum CachePolicy {
    static func entry(data: Data, response: HTTPURLResponse, now: Date, previous: CachedTile? = nil) -> CachedTile? {
        let cc = (response.value(forHTTPHeaderField: "Cache-Control") ?? "").lowercased()
        let directives = cc.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if directives.contains("no-store") { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let serverDate = response.value(forHTTPHeaderField: "Date").flatMap(formatter.date(from:)) ?? now
        let age = max(Double(response.value(forHTTPHeaderField: "Age") ?? "") ?? 0, now.timeIntervalSince(serverDate), 0)
        var lifetime: Double = 7 * 86400
        if let maxAge = directives.first(where: { $0.hasPrefix("max-age=") }),
           let seconds = Double(maxAge.dropFirst(8).replacingOccurrences(of: "\"", with: "")), seconds.isFinite {
            lifetime = max(0, seconds - age)
        } else if let expires = response.value(forHTTPHeaderField: "Expires").flatMap(formatter.date(from:)) {
            lifetime = max(0, expires.timeIntervalSince(serverDate) - age)
        }
        if directives.contains("no-cache") { lifetime = 0 }
        return CachedTile(data: data, stored: now, expires: now.addingTimeInterval(lifetime),
                          etag: response.value(forHTTPHeaderField: "ETag") ?? previous?.etag,
                          modified: response.value(forHTTPHeaderField: "Last-Modified") ?? previous?.modified,
                          mustRevalidate: directives.contains("must-revalidate") || directives.contains("no-cache"))
    }
}

/// Called exclusively on a loader's background queue. One atomic record avoids mismatched
/// image/validator pairs when separate screen-saver processes share the cache.
final class TileCache {
    let directory: URL
    init(directory: URL? = nil, namespace: String = "osm-standard") {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.someoneintexas.screensavers/\(namespace)", isDirectory: true)
    }
    func read(_ id: TileID) -> CachedTile? {
        let path = directory.appendingPathComponent(id.key + ".json")
        guard let size = try? path.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 1_000_000,
              let data = try? Data(contentsOf: path), let entry = try? JSONDecoder().decode(CachedTile.self, from: data),
              Self.decode(entry.data) != nil else { return nil }
        return entry
    }
    func write(_ entry: CachedTile?, id: TileID) {
        let path = directory.appendingPathComponent(id.key + ".json")
        guard let entry else { try? FileManager.default.removeItem(at: path); return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entry) { try? data.write(to: path, options: .atomic) }
    }
    func prune(now: Date = Date()) {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) else { return }
        let records = files.compactMap { url -> (URL, Int, Date)? in
            guard let v = try? url.resourceValues(forKeys: keys), let size = v.fileSize, let date = v.contentModificationDate else { return nil }
            return (url, size, date)
        }.sorted { $0.2 < $1.2 }
        var total = records.reduce(0) { $0 + $1.1 }
        for (url, size, date) in records where total > 192 * 1024 * 1024 && now.timeIntervalSince(date) > 7 * 86400 {
            if let data = try? Data(contentsOf: url), let entry = try? JSONDecoder().decode(CachedTile.self, from: data), entry.expires > now { continue }
            try? FileManager.default.removeItem(at: url)
            total -= size
        }
    }
    static func decode(_ data: Data) -> CGImage? {
        guard data.count <= 512_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              (info[kCGImagePropertyPixelWidth] as? Int) == 256,
              (info[kCGImagePropertyPixelHeight] as? Int) == 256 else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }
}

protocol TileCancellation { func cancel() }
extension URLSessionDataTask: TileCancellation {}
protocol TileTransport {
    func fetch(_ request: URLRequest, completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) -> TileCancellation
}
final class HTTPTransport: NSObject, TileTransport, URLSessionDataDelegate {
    private struct Transfer {
        var data = Data()
        var response: HTTPURLResponse?
        let completion: (Data?, HTTPURLResponse?, Error?) -> Void
    }
    private let lock = NSLock()
    private var transfers: [Int: Transfer] = [:]
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil // The persistent cache below owns freshness decisions.
        config.httpMaximumConnectionsPerHost = 2
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        let delegateQueue = OperationQueue(); delegateQueue.maxConcurrentOperationCount = 1
        return URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
    }()
    func fetch(_ request: URLRequest, completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) -> TileCancellation {
        let task = session.dataTask(with: request)
        lock.lock(); transfers[task.taskIdentifier] = Transfer(completion: completion); lock.unlock()
        task.resume(); return task
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        lock.lock(); transfers[dataTask.taskIdentifier]?.response = response as? HTTPURLResponse; lock.unlock()
        completionHandler(response.expectedContentLength > 512_000 ? .cancel : .allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        let total = (transfers[dataTask.taskIdentifier]?.data.count ?? 0) + data.count
        if total <= 512_000 { transfers[dataTask.taskIdentifier]?.data.append(data) }
        lock.unlock()
        if total > 512_000 { dataTask.cancel() }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock(); let transfer = transfers.removeValue(forKey: task.taskIdentifier); lock.unlock()
        transfer?.completion(transfer?.data, transfer?.response, error)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" && request.url?.host == task.originalRequest?.url?.host ? request : nil)
    }
    func invalidate() { session.invalidateAndCancel() }
}

final class TileLoader {
    private let queue = DispatchQueue(label: "screensavers.tiles", qos: .utility)
    private let cache: TileCache
    private let transport: TileTransport
    private let provider: TileProvider
    private var pending: [TileID] = []
    private var active: [TileID: TileCancellation] = [:]
    private var completed = Set<TileID>()
    private var failed = Set<TileID>()
    private var requestCount = 0
    private var stopped = false
    private var cooldown = Date.distantPast
    private let deliver: (TileID, CGImage) -> Void
    init(provider: TileProvider = .osm, cache: TileCache? = nil, transport: TileTransport? = nil,
         deliver: @escaping (TileID, CGImage) -> Void) {
        self.provider = provider; self.cache = cache ?? TileCache(namespace: provider.cacheNamespace)
        self.transport = transport ?? HTTPTransport(); self.deliver = deliver
        queue.async { [weak self] in self?.cache.prune() }
    }
    func request(_ ids: [TileID]) {
        queue.async { [weak self] in
            guard let self, !self.stopped else { return }
            // Replace the queue on resize: never finish fetching an obsolete viewport.
            let visible = Set(ids)
            for (id, task) in self.active where !visible.contains(id) { task.cancel() }
            self.pending = Array(Set(ids)).filter { !self.completed.contains($0) && !self.failed.contains($0) && self.active[$0] == nil }
                .sorted { $0.key < $1.key }
            self.pump()
        }
    }
    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopped = true; self.pending.removeAll()
            self.active.values.forEach { $0.cancel() }; self.active.removeAll()
            (self.transport as? HTTPTransport)?.invalidate()
        }
    }
    deinit { (transport as? HTTPTransport)?.invalidate() }
    private func emit(_ id: TileID, _ image: CGImage) {
        completed.insert(id)
        DispatchQueue.main.async { [weak self] in self?.deliver(id, image) }
    }
    private func pump() {
        while !stopped && active.count < 2 && !pending.isEmpty {
            let id = pending.removeFirst()
            let cached = cache.read(id)
            if let cached, cached.expires > Date(), let image = TileCache.decode(cached.data) { emit(id, image); continue }
            if let cached, !cached.mustRevalidate, let image = TileCache.decode(cached.data) { emit(id, image) }
            guard requestCount < 96, Date() >= cooldown, let url = provider.url(id) else { continue }
            requestCount += 1
            var request = URLRequest(url: url)
            request.setValue("ScreensaversForMac/\(BuildVersion.value) (+https://github.com/someone-in-texas/screensavers-for-mac)", forHTTPHeaderField: "User-Agent")
            if let etag = cached?.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            if let modified = cached?.modified { request.setValue(modified, forHTTPHeaderField: "If-Modified-Since") }
            active[id] = transport.fetch(request) { [weak self] data, response, error in
                guard let self else { return }
                self.queue.async {
                    self.active.removeValue(forKey: id)
                    guard !self.stopped else { return }
                    defer { self.pump() }
                    guard error == nil, let response else { self.failed.insert(id); return }
                    if response.statusCode == 429 || response.statusCode == 503 {
                        let delay = Double(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 300
                        self.cooldown = Date().addingTimeInterval(max(60, delay))
                        self.pending.removeAll()
                    }
                    let bytes = response.statusCode == 304 ? cached?.data : data
                    guard response.statusCode == 200 || response.statusCode == 304, let bytes,
                          response.statusCode == 304 || response.mimeType == "image/png",
                          let image = TileCache.decode(bytes) else { self.failed.insert(id); return }
                    self.cache.write(CachePolicy.entry(data: bytes, response: response, now: Date(), previous: cached), id: id)
                    self.emit(id, image)
                }
            }
        }
    }
}
