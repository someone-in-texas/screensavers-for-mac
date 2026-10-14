import Foundation

func testCommonplace() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("commonplace-tests-"+UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let archive = CommonplaceArchive(root:root)
    let now = Date(timeIntervalSince1970:1_800_000_000)
    var calendar = Calendar(identifier:.gregorian);calendar.timeZone = TimeZone(secondsFromGMT:0)!
    expect(archive.load().isEmpty && !FileManager.default.fileExists(atPath:root.path),"read-only archive does not create files")
    let dates = archive.requestedDates(now:now,calendar:calendar)
    expect(dates.count == 5 && dates == dates.sorted(),"first run has five consecutive dates")
    func bundle(_ dates:[String],prefix:String = "") throws -> Data {
        let days = dates.map { day in CommonplaceDay(date:day,title:"A useful note",entries:(0..<10).map { CommonplaceEntry(id:prefix+day+"-\($0)",kind:.observation,text:"An ordinary detail worth keeping.",tags:["detail"],replyTo:nil) },hooks:["An unanswered question"],sourceConcepts:["fern study"],fictional:true) }
        return try JSONEncoder().encode(CommonplaceBundle(schemaVersion:1,days:days))
    }
    var lock: CommonplaceGenerationLease? = try archive.acquireGenerationLease()
    do { _ = try archive.acquireGenerationLease();expect(false,"second process must not generate concurrently") } catch { expect(true,"lease excludes competing writers") }
    try archive.commit(bundle(dates),dates:dates,knownIDs:[])
    expect(archive.load().count == 5 && archive.requestedDates(now:now,calendar:calendar).isEmpty,"bootstrap committed once and same day is idempotent")
    do { try archive.commit(bundle(dates),dates:dates,knownIDs:[]);expect(false,"duplicate batch rejected") } catch { expect(true,"duplicate batch rejected") }
    for day in 1...365 {
        let next = calendar.date(byAdding:.day,value:day,to:now)!, requested = archive.requestedDates(now:next,calendar:calendar)
        expect(requested.count == 1,"only one day after bootstrap")
        try archive.commit(bundle(requested),dates:requested,knownIDs:[])
    }
    expect(archive.files().count == 366 && archive.load().count<=68,"working set bounded while all 370 days remain on disk")
    expect(archive.contains(date:dates[1]) && archive.requestedDates(now:now,calendar:calendar).isEmpty,"old date stays idempotent after large archive or clock rollback")
    expect(archive.load().contains(where:{ $0.date < CommonplaceArchive.dayKey(now.addingTimeInterval(86400*90),calendar:calendar) }),"old content remains eligible")
    let bad = Data("{\"schemaVersion\":1,\"days\":[]}".utf8)
    let prior = archive.files().count
    do { try archive.commit(bad,dates:["2027-05-01"],knownIDs:[]);expect(false,"invalid JSON structure rejected") } catch { expect(archive.files().count == prior,"invalid response leaves archive intact") }
    expect(!CommonplaceArchive.validDate("2026-02-30") && CommonplaceArchive.validDate("2028-02-29"),"strict real calendar dates")
    try archive.archiveLineage();expect(archive.load().isEmpty && archive.requestedDates(now:now,calendar:calendar).count == 5,"reset begins new five-day lineage")
    let saved = try FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil).filter { $0.lastPathComponent.hasPrefix("saved-") }
    expect(saved.count == 1 && (try? FileManager.default.contentsOfDirectory(at:saved[0],includingPropertiesForKeys:nil).count) == prior,"reset preserves all previous batches")
    lock = nil
    withExtendedLifetime(lock) {}

    func json(_ object: Any) -> Data { try! JSONSerialization.data(withJSONObject:object) }
    let publicRecord:[String:Any] = ["id":163994,"title":"Protea study","share_license_status":"CC0","url":"https://www.clevelandart.org/art/2005.336","images":["web":["url":"https://openaccess-cdn.clevelandart.org/2005.336/2005.336_web.jpg"]]]
    let publicData = try JSONSerialization.data(withJSONObject:["data":[publicRecord]])
    expect(ArchiveProvider.cleveland.candidates(publicData).count == 1,"verified per-item CC0 source accepted")
    for (key,value) in [("share_license_status","Copyrighted"),("url","https://untrusted.test/item")] {
        var record = publicRecord;record[key] = value
        expect(ArchiveProvider.cleveland.candidates(json(["data":[record]])).isEmpty,"rights and source origin enforced")
    }
    var redirectedImage = publicRecord;redirectedImage["images"] = ["web":["url":"http://localhost/private"]]
    expect(ArchiveProvider.cleveland.candidates(json(["data":[redirectedImage]])).isEmpty,"model/local image URLs cannot enter source pipeline")
    let chicago:[String:Any] = ["id":125577,"title":"Fern study","is_public_domain":true,"image_id":"047e93a7-0ee1-0b36-7ef0-db30bf5badca"]
    expect(ArchiveProvider.chicago.candidates(json(["data":[chicago]])).count == 1,"Chicago public-domain record accepted")
    var restricted = chicago;restricted["is_public_domain"] = false
    expect(ArchiveProvider.chicago.candidates(json(["data":[restricted]])).isEmpty,"copyrighted image excluded despite search filter")
    expect(ArchiveProvider.chicago.candidates(Data("malformed".utf8)).isEmpty,"malformed source response ignored")

    var unsafe = publicRecord;unsafe["title"] = "Battle with a bloodied bird"
    expect(ArchiveProvider.cleveland.candidates(json(["data":[unsafe]])).isEmpty,"ambient source filter excludes disturbing subjects")
    final class FailedSource: ArchiveHTTP {
        var calls = 0
        func get(_ url:URL,limit:Int,completion:@escaping (Result<Data,Error>)->Void) { calls += 1;completion(.failure(CommonplaceContentError.invalid("offline"))) }
    }
    let failedHTTP = FailedSource(),collector = CommonplaceSourceCollector(root:root,http:failedHTTP)
    var finished = false;collector.collect(concepts:["fern study","machine"]) { finished = true }
    expect(finished && !collector.busy && failedHTTP.calls == 2,"unavailable sources finish within bounded attempts")
    expect(archive.load().isEmpty,"source failure cannot modify daily content")
    let sample = try CommonplaceBundle.decode(bundle(dates),expectedDates:dates)
    expect(CommonplaceArchive.repeatedFraction(sample.days,previous:sample.days) == 1,"novelty rejects verbatim recent days")
    let transport = FakeTransport(), connection = CodexConnection(transport:transport)
    let session = HelperSession(connection:connection,workspace:root.appendingPathComponent("empty"),openBrowser:{ _ in false })
    let coordinator = CommonplaceCoordinator(archive:archive,collectSources:false)
    session.connect();transport.respond([:]);transport.respond(["account":["type":"chatgpt"]])
    coordinator.generate(session:session,settings:CommonplaceSettings(),now:now)
    expect(coordinator.busy && transport.method == "thread/start","coordinator starts one bounded request")
    let requestCount = transport.messages.count
    coordinator.generate(session:session,settings:CommonplaceSettings(),now:now)
    expect(transport.messages.count == requestCount,"repeated requests coalesce during generation")
    transport.respond(["thread":["id":"notebook"]]);transport.respond(["turn":["id":"turn"]])
    let generatedDates = archive.requestedDates(now:now)
    transport.notify("item/completed",["threadId":"notebook","item":["type":"agentMessage","text":String(data:try bundle(generatedDates),encoding:.utf8)!]])
    transport.notify("turn/completed",["threadId":"notebook","turn":["status":"completed"]])
    expect(!coordinator.busy && archive.load().count == 5,"successful structured response atomically creates first notebook")
    coordinator.generate(session:session,settings:CommonplaceSettings(),now:now)
    expect(transport.messages.count == requestCount+1,"saved day never creates another model request")
    session.close()
}
