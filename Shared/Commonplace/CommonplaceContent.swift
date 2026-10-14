import Foundation

enum CommonplaceTheme: String, CaseIterable, Codable { case automatic, sepia, naturalist, observatory, workshop, atomic, offWorld
    var title: String {
        switch self { case .sepia:return "Sepia Archive";case .observatory:return "Midnight Observatory";case .atomic:return "Atomic Lab";case .offWorld:return "Off-World";default:return rawValue.capitalized }
    }
}
enum CommonplacePace: String, CaseIterable, Codable { case verySlow, relaxed, normal
    var secondsPerPage: Double { self == .verySlow ? 100 : self == .relaxed ? 70 : 45 }
}
enum CommonplaceDensity: String, CaseIterable, Codable { case automatic, sparse, balanced, dense }
struct CommonplaceSettings: Codable, Equatable {
    var theme = CommonplaceTheme.sepia
    var pace = CommonplacePace.relaxed
    var density = CommonplaceDensity.automatic
    var originalWriting = true
    var diagrams = true
    var historicalImages = true
    var quotations = true
    var interests = ["Natural history", "Astronomy", "Everyday life"]
    func sanitized() -> Self {
        var copy = self
        var seen = Set<String>()
        copy.interests = interests.map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }.filter { !$0.isEmpty && $0.count<=50 && seen.insert($0).inserted }.prefix(8).map { $0 }
        return copy
    }
}

enum CommonplaceContentError: LocalizedError {
    case invalid(String), busy, duplicate
    var errorDescription: String? {
        switch self { case .invalid(let reason):return "Commonplace content rejected: \(reason)";case .busy:return "Another Commonplace generation is already running.";case .duplicate:return "This notebook day already exists." }
    }
}
struct CommonplaceEntry: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable { case observation, question, list, table, playful, reflection, callback }
    let id: String
    let kind: Kind
    let text: String
    let tags: [String]
    let replyTo: String?
}
struct CommonplaceDay: Codable, Equatable {
    let date: String
    let title: String
    let entries: [CommonplaceEntry]
    let hooks: [String]
    let sourceConcepts: [String]
    let fictional: Bool
    var candidates: [CommonplaceSourceIdea]? = nil
}
struct CommonplaceSourceIdea: Codable, Equatable {
    enum Kind: String, Codable { case quotation, fact, image }
    let kind: Kind
    let query: String
    let reason: String
}
struct CommonplaceBundle: Codable {
    let schemaVersion: Int
    let days: [CommonplaceDay]
    static let maximumBytes = 160_000
    static func decode(_ data: Data, expectedDates: [String], knownIDs: Set<String> = []) throws -> Self {
        guard data.count <= maximumBytes else { throw CommonplaceContentError.invalid("response too large") }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.schemaVersion == 1, value.days.map(\.date) == expectedDates, Set(expectedDates).count == expectedDates.count, expectedDates == expectedDates.sorted(), [1,5].contains(value.days.count) else { throw CommonplaceContentError.invalid("schema or dates") }
        var ids = knownIDs
        for day in value.days {
            guard CommonplaceArchive.validDate(day.date), day.fictional, !day.title.isEmpty, day.title.count <= 100,
                  (8...28).contains(day.entries.count), day.hooks.count <= 8, day.sourceConcepts.count <= 8,
                  (day.hooks + day.sourceConcepts).allSatisfy({ !$0.isEmpty && $0.count <= 180 }) else { throw CommonplaceContentError.invalid("day bounds") }
            if let candidates = day.candidates {
                guard candidates.count<=12,candidates.allSatisfy({ !$0.query.isEmpty && $0.query.count<=120 && $0.reason.count<=240 }) else { throw CommonplaceContentError.invalid("source ideas") }
            }
            for entry in day.entries {
                guard entry.id.hasPrefix(day.date+"-"), entry.id.count <= 80, !ids.contains(entry.id),
                      !entry.text.isEmpty, entry.text.count <= 550, entry.tags.count <= 6,
                      entry.tags.allSatisfy({ !$0.isEmpty && $0.count <= 40 }),
                      entry.replyTo == nil || ids.contains(entry.replyTo!),
                      entry.kind != .callback || entry.replyTo != nil else { throw CommonplaceContentError.invalid("entry bounds or unknown callback") }
                ids.insert(entry.id)
            }
        }
        return value
    }
}

/// Provenance is separate from generated prose. Model output never creates a
/// verified quotation or artifact. Sources must pass an explicit rights check.
struct CommonplaceArtifact: Codable, Equatable {
    let id: String
    let title: String
    let creator: String
    let sourceURL: URL
    let licenseURL: URL
    let license: String
    let attribution: String
    let localFilename: String
    var subjects: [String]? = nil
    var visualType: String? = nil
    var creationDate: String? = nil
    var medium: String? = nil
    var institution: String { sourceURL.host?.contains("clevelandart.org") == true ? "Cleveland Museum of Art" : sourceURL.host?.contains("artic.edu") == true ? "Art Institute of Chicago" : "Archival source" }
    var reusable: Bool {
        let rights = licenseURL.absoluteString
        return sourceURL.scheme == "https" && sourceURL.user == nil && sourceURL.password == nil &&
            ["https://creativecommons.org/publicdomain/zero/1.0/", "https://creativecommons.org/publicdomain/mark/1.0/"].contains(rights) &&
            ["CC0", "Public Domain Mark"].contains(license) && !attribution.isEmpty && attribution.count<=3000 && !title.isEmpty && title.count<=500 && id.count<=80 &&
            localFilename == URL(fileURLWithPath: localFilename).lastPathComponent && !localFilename.hasPrefix(".")
    }
}
