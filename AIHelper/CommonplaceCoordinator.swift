import Foundation

/// Owns the generation lease for the entire request, including validation and
/// commit. No model text is exposed to the saver before the batch is accepted.
final class CommonplaceCoordinator {
    let archive: CommonplaceArchive
    private let sources: CommonplaceSourceCollector?
    private var lease: CommonplaceGenerationLease?
    private var epoch = 0
    private(set) var status = "The starter notebook is ready offline."
    private(set) var busy = false
    var changed: (() -> Void)?
    init(archive: CommonplaceArchive = CommonplaceArchive(), collectSources: Bool = true, sourceHTTP: ArchiveHTTP? = nil) { self.archive = archive;self.sources = collectSources ? CommonplaceSourceCollector(root:archive.root,http:sourceHTTP ?? ArchiveHTTPClient()):nil }
    func generate(session:HelperSession,settings:CommonplaceSettings,now:Date = Date()) {
        guard !busy else { return }
        do {
            lease = try archive.acquireGenerationLease()
            let dates = archive.requestedDates(now:now)
            guard !dates.isEmpty else { lease = nil;status = "Today's notebook is already saved.";changed?();return }
            busy = true;epoch += 1;let attempt = epoch
            let previous = archive.load(), ids = Set(previous.flatMap(\.entries).map(\.id))
            status = dates.count == 5 ? "Creating five opening notebook days…":"Creating today's notebook…";changed?()
            session.generate(prompt:CommonplaceArchive.prompt(dates:dates,previous:previous,settings:settings)) { [weak self] result in
                guard let self, self.epoch == attempt else { return }
                defer { self.busy = false;self.lease = nil;self.changed?() }
                do {
                    let text = try result.get()
                    guard let data = text.data(using:.utf8) else { throw CommonplaceContentError.invalid("encoding") }
                    let incoming = try CommonplaceBundle.decode(data,expectedDates:dates,knownIDs:ids)
                    guard CommonplaceArchive.repeatedFraction(incoming.days,previous:previous)<0.5 else { throw CommonplaceContentError.invalid("too much repeated recent writing; try again later") }
                    try self.archive.commit(data,dates:dates,knownIDs:ids)
                    if settings.historicalImages { self.sources?.collect(concepts:self.archive.load().suffix(dates.count).flatMap(\.sourceConcepts)) {} }
                    self.status = "Saved \(dates.count) notebook \(dates.count == 1 ? "day":"days"). Last success: \(dates.last!)."
                } catch { self.status = error.localizedDescription+" Your existing notebook is unchanged." }
            }
        } catch { lease = nil;status = error.localizedDescription;changed?() }
    }
    func reset() throws {
        guard !busy else { throw CommonplaceContentError.busy }
        let lock = try archive.acquireGenerationLease();defer { withExtendedLifetime(lock) {} }
        try archive.archiveLineage();status = "Previous notebook preserved. Generate to begin five new opening days.";changed?()
    }
}
