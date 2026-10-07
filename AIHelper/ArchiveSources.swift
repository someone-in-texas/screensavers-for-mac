import Foundation
import ImageIO

protocol ArchiveHTTP {
    func get(_ url:URL,limit:Int,completion:@escaping (Result<Data,Error>)->Void)
}

/// Bounded downloads and same-provider redirects. No model-supplied URL is fetched.
final class ArchiveHTTPClient: NSObject, ArchiveHTTP, URLSessionDataDelegate, URLSessionTaskDelegate {
    private final class Request {
        let host:String, limit:Int, completion:(Result<Data,Error>)->Void
        var data = Data()
        init(host:String,limit:Int,completion:@escaping (Result<Data,Error>)->Void) { self.host = host;self.limit = limit;self.completion = completion }
    }
    private var requests:[Int:Request] = [:]
    private lazy var session:URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20;configuration.timeoutIntervalForResource = 35
        configuration.httpMaximumConnectionsPerHost = 2;configuration.urlCache = nil
        return URLSession(configuration:configuration,delegate:self,delegateQueue:.main)
    }()
    func get(_ url:URL,limit:Int,completion:@escaping (Result<Data,Error>)->Void) {
        guard url.scheme == "https",url.user == nil,url.password == nil,let host = url.host else { completion(.failure(CommonplaceContentError.invalid("source URL")));return }
        var request = URLRequest(url:url);request.setValue("ScreensaversForMac/0.9 (Commonplace archival sources)",forHTTPHeaderField:"User-Agent")
        let task = session.dataTask(with:request);requests[task.taskIdentifier] = Request(host:host,limit:limit,completion:completion);task.resume()
    }
    func urlSession(_ session:URLSession,dataTask:URLSessionDataTask,didReceive response:URLResponse,completionHandler:@escaping (URLSession.ResponseDisposition)->Void) {
        guard let request = requests[dataTask.taskIdentifier],let http = response as? HTTPURLResponse,http.statusCode == 200,response.expectedContentLength<=request.limit else { completionHandler(.cancel);return }
        completionHandler(.allow)
    }
    func urlSession(_ session:URLSession,dataTask:URLSessionDataTask,didReceive data:Data) {
        guard let request = requests[dataTask.taskIdentifier] else { return }
        guard request.data.count+data.count<=request.limit else { dataTask.cancel();return }
        request.data.append(data)
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping (URLRequest?)->Void) {
        guard let original = requests[task.taskIdentifier],request.url?.scheme == "https",request.url?.host == original.host else { completionHandler(nil);return }
        completionHandler(request)
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,didCompleteWithError error:Error?) {
        guard let request = requests.removeValue(forKey:task.taskIdentifier) else { return }
        if let error { request.completion(.failure(error)) } else { request.completion(.success(request.data)) }
    }
    func cancel() { session.invalidateAndCancel() }
}

struct ArchiveCandidate {
    let artifact:CommonplaceArtifact
    let imageURL:URL
}

enum ArchiveProvider: CaseIterable {
    case cleveland, chicago
    func searchURL(_ query:String)->URL {
        var components = URLComponents(string:self == .cleveland ? "https://openaccess-api.clevelandart.org/api/artworks/":"https://api.artic.edu/api/v1/artworks/search")!
        components.queryItems = [URLQueryItem(name:"q",value:String(query.prefix(100))),URLQueryItem(name:"limit",value:"8")]
        if self == .cleveland { components.queryItems! += [URLQueryItem(name:"cc0",value:"1"),URLQueryItem(name:"has_image",value:"1")] }
        else { components.queryItems! += [URLQueryItem(name:"query[term][is_public_domain]",value:"true"),URLQueryItem(name:"fields",value:"id,title,image_id,is_public_domain,artist_display,date_display")] }
        return components.url!
    }
    func candidates(_ data:Data)->[ArchiveCandidate] {
        guard data.count<=1_000_000,let json = try? JSONSerialization.jsonObject(with:data) as? [String:Any],let rows = json["data"] as? [[String:Any]] else { return [] }
        return rows.prefix(8).compactMap { row in
            guard let id = row["id"] as? Int, id>0,let title = row["title"] as? String,!title.isEmpty,title.count<=500 else { return nil }
            let description = title.lowercased()
            let excluded = ["nude","naked","death","dead","battle","war ","execution","wound","blood","anatomy","corpse","crucifix","martyr","gun","rifle","sword","pistol","erotic","torture","slave","slavery"]
            let subjects = ["botan","flower","fern","plant","tree","leaf","leaves","garden","landscape","bird","moth","butterfl","insect","shell","instrument","machine","mechanic","architect","building","bridge","star","celestial","astronom","map","textile","pattern","protea","camelli","heath"]
            guard !excluded.contains(where:description.contains),subjects.contains(where:description.contains) else { return nil }
            let prefix = self == .cleveland ? "cma":"artic", filename = "\(prefix)-\(id).jpg"
            let image:URL, source:URL, creator:String, credit:String
            if self == .cleveland {
                guard row["share_license_status"] as? String == "CC0",let images = row["images"] as? [String:Any],let web = images["web"] as? [String:Any],let raw = web["url"] as? String,let url = URL(string:raw),url.scheme == "https",url.host == "openaccess-cdn.clevelandart.org" else { return nil }
                guard let sourceText = row["url"] as? String,let sourceURL = URL(string:sourceText),sourceURL.scheme == "https",sourceURL.host == "www.clevelandart.org" else { return nil }
                image = url;source = sourceURL
                creator = (row["creators"] as? [[String:Any]])?.compactMap { $0["description"] as? String }.joined(separator:"; ") ?? "Artist unrecorded"
                credit = "Cleveland Museum of Art"
            } else {
                guard row["is_public_domain"] as? Bool == true,let imageID = row["image_id"] as? String,imageID.count<=80,imageID.allSatisfy({ $0.isHexDigit || $0 == "-" }) else { return nil }
                image = URL(string:"https://www.artic.edu/iiif/2/\(imageID)/full/843,/0/default.jpg")!;source = URL(string:"https://www.artic.edu/artworks/\(id)")!
                creator = row["artist_display"] as? String ?? "Artist unrecorded";credit = "Art Institute of Chicago"
            }
            var artifact = CommonplaceArtifact(id:"\(prefix)-\(id)",title:title,creator:String(creator.prefix(500)),sourceURL:source,licenseURL:URL(string:"https://creativecommons.org/publicdomain/zero/1.0/")!,license:"CC0",attribution:"\(title). \(creator). \(credit). CC0.",localFilename:filename)
            artifact.subjects = ["botan","flower","fern","plant","tree","leaf","garden","protea","camelli","heath"].contains(where:description.contains) ? ["botany"]:["machine","mechanic","instrument","bridge","architect"].contains(where:description.contains) ? ["mechanics"]:["bird","moth","butterfl","insect","shell"].contains(where:description.contains) ? ["animals"]:[]
            artifact.creationDate = (row[self == .cleveland ? "creation_date":"date_display"] as? String).map { String($0.prefix(160)) }
            artifact.medium = (row["technique"] as? String).map { String($0.prefix(300)) }
            return ArchiveCandidate(artifact:artifact,imageURL:image)
        }
    }
}

final class CommonplaceSourceCollector {
    private let http:ArchiveHTTP
    private let root:URL
    private(set) var busy = false
    init(root:URL,http:ArchiveHTTP = ArchiveHTTPClient()) { self.root = root;self.http = http }
    /// At most two images per successful notebook generation. Failure leaves the
    /// existing archive usable; source collection does not trigger model retries.
    func collect(concepts:[String],completion:@escaping ()->Void) {
        guard !busy else { completion();return };busy = true
        let safe = concepts.filter { !$0.isEmpty && $0.count<=100 }
        let queries = Array((safe.isEmpty ? ["botanical study","scientific instrument"]:safe).prefix(2))
        func next(_ index:Int) {
            guard index<queries.count else { self.busy = false;completion();return }
            let provider = ArchiveProvider.allCases[index%2]
            http.get(provider.searchURL(queries[index]),limit:1_000_000) { result in
                guard case .success(let data) = result,let candidate = provider.candidates(data).first(where:{ !FileManager.default.fileExists(atPath:self.root.appendingPathComponent("sources/"+$0.artifact.id+".json").path) }) else { next(index+1);return }
                self.http.get(candidate.imageURL,limit:5_000_000) { result in
                    if case .success(let data) = result { try? self.save(candidate,data:data) }
                    next(index+1)
                }
            }
        }
        next(0)
    }
    private func save(_ candidate:ArchiveCandidate,data:Data) throws {
        guard candidate.artifact.reusable,let source = CGImageSourceCreateWithData(data as CFData,nil),let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],let width = properties[kCGImagePropertyPixelWidth] as? Int,let height = properties[kCGImagePropertyPixelHeight] as? Int,width>0,height>0,width<=16000,height<=16000,
              let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1200] as CFDictionary) else { throw CommonplaceContentError.invalid("source image") }
        let media = root.appendingPathComponent("media"), metadata = root.appendingPathComponent("sources")
        try FileManager.default.createDirectory(at:media,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700]);try FileManager.default.createDirectory(at:metadata,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        let bytes = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(bytes,"public.jpeg" as CFString,1,nil) else { return }
        CGImageDestinationAddImage(destination,image,[kCGImageDestinationLossyCompressionQuality:0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return }
        try (bytes as Data).write(to:media.appendingPathComponent(candidate.artifact.localFilename),options:.atomic)
        try JSONEncoder().encode(candidate.artifact).write(to:metadata.appendingPathComponent(candidate.artifact.id+".json"),options:.atomic)
        // Keep all provenance; old downloadable media can be evicted independently.
        let files = try FileManager.default.contentsOfDirectory(at:media,includingPropertiesForKeys:[.contentModificationDateKey]).sorted { ((try? $0.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast) < ((try? $1.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
        for file in files.prefix(max(0,files.count-120)) { try? FileManager.default.removeItem(at:file) }
    }
}
