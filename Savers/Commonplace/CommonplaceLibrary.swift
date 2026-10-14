import AppKit
import ImageIO

struct CommonplaceLibrary {
    let days: [CommonplaceDay]
    let artifacts: [(CommonplaceArtifact, CGImage)]
    init(archive: CommonplaceArchive?, resources: URL? = nil) {
        let stored = archive?.load() ?? []
        days = stored.isEmpty ? Self.starter : stored
        let directory = resources ?? Bundle(for: CommonplaceScene.self).resourceURL?.appendingPathComponent("Commonplace")
        var images: [(CommonplaceArtifact, CGImage)] = []
        if let directory, let data = try? Data(contentsOf:directory.appendingPathComponent("catalog.json")), data.count < 500_000,
           let catalog = try? JSONDecoder().decode([CommonplaceArtifact].self,from:data) {
            for entry in catalog.prefix(32) where entry.reusable {
                if let source = CGImageSourceCreateWithURL(directory.appendingPathComponent(entry.localFilename) as CFURL,nil),
                   let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1200] as CFDictionary) { images.append((entry,image)) }
            }
        }
        if let archive {
            let metadata = archive.root.appendingPathComponent("sources"), media = archive.root.appendingPathComponent("media")
            let files = ((try? FileManager.default.contentsOfDirectory(at:metadata,includingPropertiesForKeys:[.isSymbolicLinkKey,.fileSizeKey,.contentModificationDateKey])) ?? []).sorted { ((try? $0.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
            for file in files.prefix(120) {
                guard let attributes = try? file.resourceValues(forKeys:[.isSymbolicLinkKey,.fileSizeKey]),attributes.isSymbolicLink != true,(attributes.fileSize ?? Int.max)<12000,
                      let data = try? Data(contentsOf:file),let entry = try? JSONDecoder().decode(CommonplaceArtifact.self,from:data),entry.reusable else { continue }
                let imageURL = media.appendingPathComponent(entry.localFilename)
                guard let values = try? imageURL.resourceValues(forKeys:[.isSymbolicLinkKey,.fileSizeKey]),values.isSymbolicLink != true,(values.fileSize ?? Int.max)<5_000_000,
                      let source = CGImageSourceCreateWithURL(imageURL as CFURL,nil),let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1000] as CFDictionary) else { continue }
                if !images.contains(where:{ $0.0.id == entry.id }) { images.append((entry,image)) }
                if images.count>=24 { break }
            }
        }
        artifacts = images
    }
    func days(for theme:CommonplaceTheme)->[CommonplaceDay] {
        guard theme == .offWorld,days.allSatisfy({ $0.date.hasPrefix("2000-") }) else { return days }
        let lines = [
            "Greenhouse pane three has misted at the lower corner again. Wipe it before the morning light reaches the seedlings.",
            "For the next maintenance round:\ncloth tape\na clean filter\nthe small wrench\na fresh pencil",
            "The basil cutting has rooted. Keep this pot beside the warmer pipe for another week.",
            "A loose latch on the storage cabinet. Tightening the lower screw helped, but the upper hole needs a small washer.",
            "Saved this picture of an Earth garden. The uneven path is the part I look at longest.",
            "The message from home arrived during the quiet shift. They have painted the kitchen yellow.",
            "Which seedlings lean toward the window, and which toward the work light? Mark the pots before moving either lamp.",
            "Measure the replacement shelf twice. There is only one spare board of this length.",
            "The clean filter made the fan quieter. It is easier to hear the clock now.",
            "Tomorrow: check the pane seal, water the basil, finish the letter."
        ]
        return [CommonplaceDay(date:"2000-01-01",title:"Greenhouse / quiet shift",entries:lines.enumerated().map { index,line in CommonplaceEntry(id:"offworld-starter-\(index)",kind:line.contains("?") ? .question:line.contains("|") ? .table:line.contains("\n") ? .list:.observation,text:line,tags:["starter","imagined habitat"],replyTo:nil) },hooks:[],sourceConcepts:[],fictional:true)]
    }
    static let starter: [CommonplaceDay] = {
        let notes: [[String]] = [
            ["Two fern shadows on the sill at 7:40. The lamp makes the smaller one. Draw their outlines before moving the pot.","Dry the seeds on a folded sheet. Label the small envelope with the date before putting them away.","Which end of a curled frond moves first? Leave a mark on the glass and look again tomorrow.","Things found in the coat pocket:\na receipt\na smooth stone\nthe missing button, at last","The kettle clicks twice before it boils. About fifteen seconds between the clicks this morning.","Pencil test: the soft lead is kinder to this paper. Keep the hard one for labels.","Rain from early morning until noon. The chair under the eaves stayed dry except for its front edge.","Tomorrow: measure the newest frond from the base of the stem."],
            ["Small grey moth on the window frame. Wings held flat, with one darker line near each outer edge.","Clouds through the skylight, in order:\nlong grey shelf\nsmall bright opening\nno shelf at all","The little gear rolls downhill in a curve. Check the axle before blaming the table.","Could a sundial record a cloudy day by the absence of a mark?","Sort the string drawer. Keep the cotton lengths together; wind the longer piece around a card.","The fern's window shadow was gone by 8:10. Its lamp shadow stayed sharp after dark.","Draw the hinge open, then closed. There is more space inside it than the first sketch suggests.","Supplies: cream paper, soft pencil leads, two small envelopes. Check the cupboard for glue first."],
            ["Cup ring near the lower margin. This paper absorbs water quickly; try the heavier sheet for the next wash.","Morning light reaches the shelf at a steeper angle now. The blue bottle throws its color onto the wall.","Unresolved:\nwhere the spare key went\nwhether the ticking is the clock\nwhy the clock has stopped","First paper boat: bottom softened after three minutes. The folds at the bow held longer than the flat center.","The pocket stone is darker when wet. Make two swatches, then wait for one to disappear.","Try drawing the spaces between the stems instead of the stems.","The hinge sketch needs one less line. Find it before adding three more.","Upstairs window faces the open yard. Turn off the desk lamp before trying to see the stars."],
            ["Rubbed a little wax along the drawer runners. It now opens without catching at the back.","Found one seed in the notebook crease. Pale brown, about 3 mm across. Keep it with the labeled envelope.","Window shadow | Length\n11:00 | 14 cm\n12:00 | 9 cm\nRepeat tomorrow from the marked edge.","For the small shelf:\ntwo brackets\nfour screws\none spirit level\na less optimistic estimate","The blue reflection has moved onto the ceiling. The bottle has not moved at all.","Could the rain be collected in separate jars by how it sounded?","Move the arrow on the hinge sketch. It should end at the pin, not the outer plate.","The gear still turns in a curve. Rotate the table and try again."],
            ["Two new leaves. The older ones have made room without appearing to move.","At dusk the window becomes a mirror. For a few minutes the room and the garden occupy the same place.","Found the spare key in the string drawer. Put it on the hook inside the cupboard.","Things to keep:\nthe useful scrap\nthe unsuccessful sketch\nthe envelope with the date on it","The soft pencil is down to 6 cm. Fit it into the wooden extender.","Compare today's frond with the mark on the glass. The answer may need another day.","Second boat, heavier paper: still dry after seven minutes. Raised the sides by one fold; kept the bow the same.","Tomorrow: finish the lower hinge view and add the missing dimension."]]
        return notes.enumerated().map { day, lines in
            let date = String(format:"2000-01-%02d",day+1)
            return CommonplaceDay(date:date,title:["Window studies","Small mechanisms","Light on the shelf","A useful scrap","Room for another leaf"][day],entries:lines.enumerated().map { i,line in
                CommonplaceEntry(id:"starter-\(day)-\(i)",kind:(day == 1 && i == 5) || (day == 4 && i == 6) ? .callback : line.contains("?") ? .question:line.contains("|") ? .table:line.contains("\n") ? .list:.observation,text:line,tags:["starter"],replyTo:day == 1 && i == 5 ? "starter-0-0":day == 4 && i == 6 ? "starter-2-3":nil)
            },hooks:[],sourceConcepts:[],fictional:true)
        }
    }()
}

/// Bounded persisted history stores IDs only. A saver never writes notebook
/// content or starts generation; multiple displays have independent shuffle seeds.
struct CommonplaceSelection: Codable {
    var recentEntries: [String] = []
    var recentLayouts: [Int] = []
    var recentArtifacts: [String] = []
    var chapterDate: String?
    var pagesInChapter = 0
    var chapterLength = 3
    var recentQuotations: [Int] = []
    var recentPairs: [String] = []
    var sequence: UInt64
    init(seed: UInt64) { sequence = seed }
    mutating func artifact(for entries:[CommonplaceEntry],available:[CommonplaceArtifact],theme:CommonplaceTheme)->Int? {
        guard !available.isEmpty else { return nil }
        let words = (entries.first?.text ?? "").lowercased()
        let botany = ["leaf","fern","seed","flower","garden","plant","frond"].contains(where:words.contains)
        let mechanics = ["gear","hinge","shelf","drawer","bracket","measure"].contains(where:words.contains)
        let animals = ["moth","bird","wing","butterfly"].contains(where:words.contains)
        var random = ArtRandom(state:sequence &+ 31)
        let ranked = available.enumerated().map { index,item -> (Int,Double) in
            let title = item.title.lowercased(), subjects = item.subjects ?? [], pair = (entries.first?.id ?? "")+"/"+item.id
            var score = random.next()*2
            if recentArtifacts.contains(item.id) { score -= 8 }
            if recentPairs.contains(pair) { score -= 20 }
            if botany && subjects.contains("botany") { score += 5 }
            if mechanics && subjects.contains("mechanics") { score += 5 }
            if animals && subjects.contains("animals") { score += 5 }
            if theme == .naturalist && title.contains("botanical") { score += 2 }
            if theme == .workshop && item.visualType == "engineering" { score += 2 }
            return (index,score)
        }
        let best = ranked.max { $0.1<$1.1 }!
        // A relevant original study is better than a spurious archival pairing.
        if (botany || mechanics || animals), best.1<3 { return nil }
        let index = best.0, chosen = available[index]
        recentArtifacts = Array((recentArtifacts+[chosen.id]).suffix(min(6,max(1,available.count-1))))
        recentPairs = Array((recentPairs+[(entries.first?.id ?? "")+"/"+chosen.id]).suffix(60))
        return index
    }
    mutating func quotation()->Int? {
        var random = ArtRandom(state:sequence &+ 100_003)
        guard random.next()<0.15 else { return nil }
        let choices = CommonplaceQuotation.verified.indices.filter { !recentQuotations.contains($0) }
        guard !choices.isEmpty else { return nil }
        let index = choices[Int(random.next()*Double(choices.count))]
        recentQuotations = Array((recentQuotations+[index]).suffix(2));return index
    }
    mutating func next(days:[CommonplaceDay], density:CommonplaceDensity) -> (day:CommonplaceDay, entries:[CommonplaceEntry], layout:Int) {
        var random = ArtRandom(state:sequence);sequence = sequence &+ 7919
        let all = days.isEmpty ? CommonplaceLibrary.starter:days
        let day: CommonplaceDay
        if pagesInChapter<chapterLength,let previous = all.first(where:{ $0.date == chapterDate }) { day = previous }
        else {
            let recent = Array(all.suffix(min(14,all.count))), older = Array(all.dropLast(recent.count))
            let pool = !older.isEmpty && random.next()<0.28 ? older:recent
            day = pool[Int(random.next()*Double(pool.count))];chapterDate = day.date;pagesInChapter = 0;chapterLength = 2+Int(random.next()*4)
        }
        pagesInChapter += 1
        var candidates = day.entries.filter { !recentEntries.contains($0.id) }
        if candidates.isEmpty { candidates = day.entries.sorted { (recentEntries.firstIndex(of:$0.id) ?? -1)<(recentEntries.firstIndex(of:$1.id) ?? -1) };candidates = Array(candidates.prefix(2)) }
        // Fisher-Yates with a local deterministic generator, independent of clocks.
        for i in candidates.indices.reversed() where i>0 { candidates.swapAt(i,Int(random.next()*Double(i+1))) }
        let roll = random.next(), count = density == .sparse ? 1 : density == .dense ? 5 : density == .balanced ? 3 : roll<0.3 ? 1 : roll<0.8 ? 3:5
        let entries = Array(candidates.prefix(count))
        let available = (0..<18).filter { !recentLayouts.contains($0) }
        let layout = available[Int(random.next()*Double(available.count))]
        recentEntries = Array((recentEntries+entries.map(\.id)).suffix(30));recentLayouts = Array((recentLayouts+[layout]).suffix(8))
        return (day,entries,layout)
    }
}
