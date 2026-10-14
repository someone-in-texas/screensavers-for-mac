import AppKit
import QuartzCore
import ImageIO

final class CommonplaceScene: SaverScene {
    private var settings = CommonplaceSettings()
    private var clock = MotionClock(), running = false
    private let seed: UInt64
    private let archive: CommonplaceArchive?
    private let resources: URL?
    private let historyURL: URL?
    private var library: CommonplaceLibrary?
    private var selection: CommonplaceSelection
    private var page = CALayer(), departing = CALayer(), desk = CALayer()
    private var pageNumber = -1, themeNumber = -1
    private var currentTheme = CommonplaceTheme.sepia
    private var lastSize = CGSize.zero
    private var rebuild = true
    private(set) var renderedPages = 0
    private(set) var currentLayout = 0
    init(seed: UInt64 = UInt64.random(in:1...UInt64.max), archive: CommonplaceArchive? = CommonplaceArchive(), resources: URL? = nil, persistHistory: Bool = false) {
        CommonplaceHandwriting.register(resources:resources)
        self.seed = seed;self.archive = archive;self.resources = resources;selection = CommonplaceSelection(seed:seed)
        historyURL = persistHistory ? archive?.root.appendingPathComponent("display-history.json"):nil
        if let url = historyURL,let history = Self.readHistory(url) {
            selection.recentEntries = Array(history.recentEntries.suffix(30));selection.recentArtifacts = Array(history.recentArtifacts.suffix(6));selection.recentLayouts = Array(history.recentLayouts.suffix(8));selection.recentPairs = Array(history.recentPairs.suffix(60))
        }
    }
    private static func readHistory(_ url:URL)->CommonplaceSelection? {
        guard let values = try? url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey]),values.isRegularFile == true,values.isSymbolicLink != true,(values.fileSize ?? Int.max)<24000,
              let data = try? Data(contentsOf:url) else { return nil }
        return try? JSONDecoder().decode(CommonplaceSelection.self,from:data)
    }
    func configuration(store:SettingsStore,changed:@escaping (SaverSettings)->Void)->SaverConfiguration? { let controller = CommonplaceConfiguration(store:store,changed:changed);controller.archive = archive;return controller }
    func start() { guard !running else { return };running = true;clock.pause();library = CommonplaceLibrary(archive:archive,resources:resources) }
    func stop() { running = false;clock.pause() }
    func apply(_ value:SaverSettings) { if settings != value.commonplace { settings = value.commonplace;rebuild = true } }
    private var colors:(desk:NSColor,paper:NSColor,ink:NSColor,accent:NSColor) {
        switch currentTheme {
        case .naturalist:return (NSColor(srgbRed:0.22,green:0.28,blue:0.22,alpha:1),NSColor(srgbRed:0.89,green:0.89,blue:0.77,alpha:1),NSColor(srgbRed:0.22,green:0.29,blue:0.21,alpha:1),NSColor(srgbRed:0.46,green:0.38,blue:0.22,alpha:1))
        case .observatory:return (NSColor(srgbRed:0.045,green:0.075,blue:0.11,alpha:1),NSColor(srgbRed:0.13,green:0.20,blue:0.28,alpha:1),NSColor(srgbRed:0.81,green:0.82,blue:0.72,alpha:1),NSColor(srgbRed:0.68,green:0.52,blue:0.29,alpha:1))
        case .workshop:return (NSColor(srgbRed:0.29,green:0.27,blue:0.23,alpha:1),NSColor(srgbRed:0.84,green:0.81,blue:0.68,alpha:1),NSColor(srgbRed:0.22,green:0.25,blue:0.26,alpha:1),NSColor(srgbRed:0.55,green:0.29,blue:0.20,alpha:1))
        case .atomic:return (NSColor(srgbRed:0.28,green:0.36,blue:0.36,alpha:1),NSColor(srgbRed:0.94,green:0.91,blue:0.78,alpha:1),NSColor(srgbRed:0.19,green:0.29,blue:0.29,alpha:1),NSColor(srgbRed:0.69,green:0.30,blue:0.20,alpha:1))
        case .offWorld:return (NSColor(srgbRed:0.22,green:0.21,blue:0.25,alpha:1),NSColor(srgbRed:0.80,green:0.81,blue:0.77,alpha:1),NSColor(srgbRed:0.26,green:0.25,blue:0.28,alpha:1),NSColor(srgbRed:0.62,green:0.35,blue:0.23,alpha:1))
        default:return (NSColor(srgbRed:0.32,green:0.28,blue:0.23,alpha:1),NSColor(srgbRed:0.91,green:0.86,blue:0.74,alpha:1),NSColor(srgbRed:0.29,green:0.24,blue:0.18,alpha:1),NSColor(srgbRed:0.51,green:0.29,blue:0.21,alpha:1))
        }
    }
    private func lettering(_ string:String,rect:CGRect,size:CGFloat,face:String = "Baskerville",color:NSColor,spacing:CGFloat = 3) {
        if face == CommonplaceHandwriting.face { CommonplaceHandwriting.draw(string,rect:rect,size:size,color:color);return }
        let style = NSMutableParagraphStyle();style.lineSpacing = spacing;style.lineBreakMode = .byWordWrapping
        (string as NSString).draw(with:rect,options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:NSFont(name:face,size:size) ?? NSFont.systemFont(ofSize:size),.foregroundColor:color,.paragraphStyle:style])
    }
    private func measuredHeight(_ string:String,width:CGFloat,size:CGFloat,face:String)->CGFloat {
        if face == CommonplaceHandwriting.face { return CommonplaceHandwriting.height(string,width:width,size:size) }
        let style = NSMutableParagraphStyle();style.lineSpacing = 3;style.lineBreakMode = .byWordWrapping
        return ceil((string as NSString).boundingRect(with:CGSize(width:width,height:10000),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:NSFont(name:face,size:size) ?? NSFont.systemFont(ofSize:size),.paragraphStyle:style]).height)
    }
    private struct NotePassage {
        let text: String, rect: CGRect, size: CGFloat, face: String, color: NSColor
    }
    /// Share the real flow between ink and its paper support, including callbacks.
    private func notePassages(_ notes: [CommonplaceEntry], grammar: CommonplaceLayout, ink: NSColor) -> [NotePassage] {
        let columns = grammar.columns
        let width = grammar.note.width/Double(columns)-Double(columns-1)*20
        var column = 0, y = grammar.note.maxY, passages: [NotePassage] = []
        for entry in notes {
            let handwritten = entry.kind != .table
            let face = handwritten ? CommonplaceHandwriting.face:"Menlo"
            var size = handwritten ? (notes.count == 1 ? 32.0:notes.count>3 ? 24.0:27.0):19.0
            var height = measuredHeight(entry.text,width:width,size:size,face:face)+4
            while height>grammar.note.height && size>12 { size -= 1;height = measuredHeight(entry.text,width:width,size:size,face:face)+4 }
            if y-height < grammar.note.minY { column += 1;y = grammar.note.maxY }
            guard column<columns, height<=grammar.note.height else { continue }
            let rect = CGRect(x:grammar.note.minX+Double(column)*(width+40),y:y-height,width:width,height:height)
            passages.append(NotePassage(text:entry.text,rect:rect,size:size,face:face,color:ink.withAlphaComponent(handwritten ? 0.85:0.96)))
            y -= height+(handwritten ? 28:22)
            if let id = entry.replyTo,let earlier = library?.days.flatMap(\.entries).first(where:{ $0.id == id }) {
                let excerpt = "Earlier: "+String(earlier.text.prefix(120))+(earlier.text.count>120 ? "…":"")
                let height = measuredHeight(excerpt,width:width-8,size:12,face:"Baskerville-Italic")+8
                if y-height>=grammar.note.minY {
                    passages.append(NotePassage(text:excerpt,rect:CGRect(x:rect.minX+8,y:y-height,width:width-8,height:height),size:12,face:"Baskerville-Italic",color:colors.accent))
                    y -= height+18
                }
            }
        }
        return passages
    }
    private func makePage(size:CGSize,number:Int)->CGImage? {
        let aspect = Double(size.width/size.height)
        let w = aspect<0.9 ? 1050.0 : 1500.0
        let h = min(4096,max(400,w/aspect))
        let rasterScale = min(2.0,4096/max(w,h))
        guard let c = bitmap(width:Int(w*rasterScale),height:Int(h*rasterScale)) else { return nil }
        c.scaleBy(x:rasterScale,y:rasterScale)
        let p = colors
        var random = ArtRandom(state:seed &+ UInt64(number)*3719)
        let selected = selection.next(days:library?.days(for:currentTheme) ?? [],density:settings.density)
        currentLayout = selected.layout;renderedPages += 1
        let layout = selected.layout, grammar = CommonplaceLayout(index:selected.layout,width:w,height:h,theme:currentTheme)
        let spread = grammar.support == .spread
        let noteInk = currentTheme == .observatory ? NSColor(srgbRed:0.28,green:0.27,blue:0.23,alpha:1):p.ink
        let passages = settings.originalWriting ? notePassages(selected.entries,grammar:grammar,ink:noteInk):[]
        let margin = 95.0, sheet = CGRect(x:margin,y:55,width:w-2*margin,height:h-110)
        // Leave the margins transparent: the persistent tabletop stays underneath.
        c.saveGState();c.setShadow(offset:CGSize(width:7,height:-10),blur:25,color:NSColor.black.withAlphaComponent(0.35).cgColor)
        c.setFillColor(p.paper.cgColor)
        let outline = CGMutablePath()
        outline.move(to:CGPoint(x:sheet.minX+2,y:sheet.minY+3))
        for i in 0...30 { outline.addLine(to:CGPoint(x:sheet.minX+Double(i)*sheet.width/30,y:sheet.minY+random.next()*2)) }
        for i in 0...20 { outline.addLine(to:CGPoint(x:sheet.maxX-random.next()*2,y:sheet.minY+Double(i)*sheet.height/20)) }
        for i in 0...30 { outline.addLine(to:CGPoint(x:sheet.maxX-Double(i)*sheet.width/30,y:sheet.maxY-random.next()*2)) }
        for i in 0...20 { outline.addLine(to:CGPoint(x:sheet.minX+random.next()*2,y:sheet.maxY-Double(i)*sheet.height/20)) };outline.closeSubpath()
        c.addPath(outline);c.fillPath();c.restoreGState()
        c.saveGState();c.clip(to:sheet)
        // Cached at page construction, never per animation frame.
        for _ in 0..<48000 {
            let x = margin+random.next()*sheet.width,y = 55+random.next()*sheet.height
            c.setStrokeColor(p.ink.withAlphaComponent(0.018+random.next()*0.026).cgColor);c.setLineWidth(0.6)
            c.move(to:CGPoint(x:x,y:y));c.addLine(to:CGPoint(x:x+random.next()*3+1,y:y+random.next()));c.strokePath()
        }
        if [.workshop,.atomic,.offWorld].contains(currentTheme) || [4,9,15].contains(layout) {
            c.setLineWidth(0.45);c.setStrokeColor(p.ink.withAlphaComponent(0.09).cgColor)
            let step = currentTheme == .atomic ? 24.0:32.0
            for x in stride(from:sheet.minX+25,to:sheet.maxX,by:step) { c.move(to:CGPoint(x:x,y:sheet.minY));c.addLine(to:CGPoint(x:x,y:sheet.maxY)) }
            for y in stride(from:sheet.minY+25,to:sheet.maxY,by:step) { c.move(to:CGPoint(x:sheet.minX,y:y));c.addLine(to:CGPoint(x:sheet.maxX,y:y)) };c.strokePath()
        }
        let wash = CGGradient(colorsSpace:nil,colors:[NSColor.white.withAlphaComponent(0.09).cgColor,p.accent.withAlphaComponent(0.04).cgColor,NSColor.clear.cgColor] as CFArray,locations:[0,0.55,1])!
        c.drawRadialGradient(wash,startCenter:CGPoint(x:w*0.27,y:h*0.72),startRadius:10,endCenter:CGPoint(x:w*0.27,y:h*0.72),endRadius:w*0.67,options:[])
        if grammar.support == .card || grammar.support == .clipping || currentTheme == .observatory {
            var inset = grammar.note.insetBy(dx:-22,dy:-24)
            let bottom = passages.map { $0.rect.minY }.min() ?? grammar.note.maxY
            let height = max(95,grammar.note.maxY-bottom+48)
            inset.origin.y = grammar.note.maxY+24-height;inset.size.height = height
            c.setShadow(offset:CGSize(width:2,height:-3),blur:5,color:p.ink.withAlphaComponent(0.16).cgColor)
            c.setFillColor((currentTheme == .observatory ? NSColor(srgbRed:0.81,green:0.78,blue:0.63,alpha:1):p.paper.blended(withFraction:0.17,of:.white)!).cgColor)
            c.fill(inset);c.setShadow(offset:.zero,blur:0,color:nil)
            for _ in 0..<1600 {
                let x = inset.minX+random.next()*inset.width,y = inset.minY+random.next()*inset.height
                c.setStrokeColor(p.ink.withAlphaComponent(0.025).cgColor);c.setLineWidth(0.45);c.move(to:CGPoint(x:x,y:y));c.addLine(to:CGPoint(x:x+random.next()*3,y:y+random.next()*0.7));c.strokePath()
            }
            if grammar.support == .card { c.setStrokeColor(p.accent.withAlphaComponent(0.26).cgColor);c.move(to:CGPoint(x:inset.minX+15,y:inset.maxY-15));c.addLine(to:CGPoint(x:inset.maxX-15,y:inset.maxY-15));c.strokePath() }
        }
        if spread {
            let gradient = CGGradient(colorsSpace:nil,colors:[NSColor.clear.cgColor,p.ink.withAlphaComponent(0.12).cgColor,NSColor.clear.cgColor] as CFArray,locations:[0,0.5,1])!
            c.drawLinearGradient(gradient,start:CGPoint(x:w/2-24,y:0),end:CGPoint(x:w/2+24,y:0),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
        }
        c.restoreGState()
        if currentTheme == .offWorld {
            c.setFillColor(p.desk.withAlphaComponent(0.60).cgColor)
            for y in stride(from:sheet.minY+40,to:sheet.maxY-20,by:48) { c.fillEllipse(in:CGRect(x:sheet.minX+16,y:y,width:8,height:8)) }
        } else if currentTheme == .naturalist {
            c.setFillColor(p.paper.blended(withFraction:0.24,of:.white)!.withAlphaComponent(0.60).cgColor)
            c.fill(CGRect(x:grammar.picture.midX-35,y:grammar.picture.maxY-6,width:70,height:13))
        } else if currentTheme == .workshop {
            let overlay = grammar.picture.insetBy(dx:-20,dy:-16)
            c.setFillColor(NSColor.white.withAlphaComponent(0.15).cgColor);c.fill(overlay)
            c.setStrokeColor(p.ink.withAlphaComponent(0.14).cgColor);c.stroke(overlay)
        } else if currentTheme == .atomic {
            c.setStrokeColor(NSColor(srgbRed:0.22,green:0.43,blue:0.53,alpha:0.20).cgColor)
            for y in stride(from:grammar.note.minY,to:grammar.note.maxY,by:30) { c.move(to:CGPoint(x:grammar.note.minX-15,y:y));c.addLine(to:CGPoint(x:grammar.note.maxX+12,y:y));c.strokePath() }
        }
        let face = CommonplaceHandwriting.face
        let left = grammar.title.x, top = grammar.title.y, width = sheet.maxX-60-grammar.title.x
        withAppKit(c) {
            if layout%4 == 0 { lettering("FIELD NOTES    /    \(String(format:"%03d",number+1))",rect:CGRect(x:left,y:top-18,width:width,height:25),size:11,face:"Menlo",color:p.accent) }
            let heading = currentTheme == .atomic ? "OBSERVATION RECORD" : currentTheme == .workshop ? "Bench notes" : currentTheme == .observatory ? "After dusk" : currentTheme == .offWorld ? "Habitat notebook / quiet shift" : selected.day.title
            var headingSize = currentTheme == .atomic || currentTheme == .offWorld ? 32.0:42.0
            while headingSize>18 && measuredHeight(heading,width:width,size:headingSize,face:face)>54 { headingSize -= 1 }
            lettering(heading,rect:CGRect(x:left,y:top-85,width:width,height:54),size:headingSize,face:face,color:p.ink)
            let stamp = selected.day.date.hasPrefix("2000-") ? "Undated · starter notebook" : selected.day.date
            lettering(stamp,rect:CGRect(x:left,y:top-116,width:width,height:24),size:13,face:"Menlo",color:p.ink.withAlphaComponent(0.65))
        }
        let artRect = grammar.picture
        if artRect.width>0,settings.quotations,let quoteIndex = selection.quotation() {
            let quote = CommonplaceQuotation.verified[quoteIndex]
            let text = "“"+quote.text+"”"
            let maximumHeight = max(110,artRect.height-80)
            var quoteSize = 27.0
            while quoteSize>16 && measuredHeight(text,width:artRect.width,size:quoteSize,face:CommonplaceHandwriting.face)>maximumHeight { quoteSize -= 1 }
            let bodyHeight = measuredHeight(text,width:artRect.width,size:quoteSize,face:CommonplaceHandwriting.face)
            let totalHeight = bodyHeight+80
            let rect = CGRect(x:artRect.minX,y:artRect.midY-totalHeight/2,width:artRect.width,height:totalHeight)
            withAppKit(c) {
                lettering("PUBLIC-DOMAIN EXTRACT",rect:CGRect(x:rect.minX,y:rect.maxY-20,width:rect.width,height:20),size:10,face:"Menlo",color:p.accent)
                lettering(text,rect:CGRect(x:rect.minX,y:rect.minY+45,width:rect.width,height:bodyHeight),size:quoteSize,face:CommonplaceHandwriting.face,color:p.ink)
                lettering(quote.attribution,rect:CGRect(x:rect.minX,y:rect.minY,width:rect.width,height:36),size:11,face:"Baskerville",color:p.ink.withAlphaComponent(0.75))
            }
        } else if currentTheme == .observatory,settings.diagrams,artRect.width>0 {
            diagram(c,rect:artRect,variant:7,color:p.ink)
            withAppKit(c) { lettering("Sky study · imagined observation",rect:CGRect(x:artRect.minX,y:artRect.minY-20,width:artRect.width,height:20),size:11,face:"Menlo",color:p.ink.withAlphaComponent(0.70)) }
        } else if artRect.width>0, settings.historicalImages, let library, !library.artifacts.isEmpty,
           let chosen = selection.artifact(for:selected.entries,available:library.artifacts.map { $0.0 },theme:currentTheme) {
            let asset = library.artifacts[chosen]
            let imageArea = CGRect(x:artRect.minX,y:artRect.minY+90,width:artRect.width,height:max(1,artRect.height-90))
            let image = asset.1, ratio = min(imageArea.width/Double(image.width),imageArea.height/Double(image.height))
            let frame = CGRect(x:imageArea.midX-Double(image.width)*ratio/2,y:imageArea.midY-Double(image.height)*ratio/2,width:Double(image.width)*ratio,height:Double(image.height)*ratio)
            c.saveGState();c.translateBy(x:frame.midX,y:frame.midY);c.rotate(by:(random.next()-0.5)*0.025);c.translateBy(x:-frame.midX,y:-frame.midY)
            c.setShadow(offset:CGSize(width:2,height:-3),blur:5,color:p.ink.withAlphaComponent(0.24).cgColor);c.setFillColor(p.paper.blended(withFraction:0.15,of:.white)!.cgColor);c.fill(frame.insetBy(dx:-10,dy:-10));c.setShadow(offset:.zero,blur:0,color:nil);c.draw(image,in:frame);c.restoreGState()
            let captionWidth = max(180,frame.width)
            let captionX = min(artRect.maxX-captionWidth,frame.minX)
            withAppKit(c) {
                var caption = asset.0.title.count>82 ? String(asset.0.title.prefix(79))+"…":asset.0.title
                while caption.count>8 && measuredHeight(caption,width:captionWidth,size:11,face:"Baskerville")>30 { caption = String(caption.dropLast(4))+"…" }
                lettering(caption,rect:CGRect(x:captionX,y:frame.minY-40,width:captionWidth,height:30),size:11,face:"Baskerville",color:p.ink.withAlphaComponent(0.75),spacing:1)
                lettering(asset.0.institution+" · "+asset.0.license,rect:CGRect(x:captionX,y:frame.minY-60,width:captionWidth,height:18),size:10,face:"Menlo",color:p.ink.withAlphaComponent(0.75),spacing:0)
                if let period = asset.0.creationDate {
                    let detail = period+(asset.0.medium.map { " · "+$0 } ?? "")
                    lettering(String(detail.prefix(110)),rect:CGRect(x:captionX,y:frame.minY-87,width:captionWidth,height:25),size:10,face:"Baskerville-Italic",color:p.ink.withAlphaComponent(0.65),spacing:0)
                }
            }
        } else if artRect.width>0, settings.diagrams { diagram(c,rect:artRect,variant:studyVariant(selected.entries),color:p.ink) }
        if settings.originalWriting {
            withAppKit(c) {
                for passage in passages {
                    lettering(passage.text,rect:passage.rect,size:passage.size,face:passage.face,color:passage.color)
                }
                lettering("Fictional notebook · \(String(format:"%03d",number+1))",rect:CGRect(x:margin+65,y:80,width:width,height:20),size:10,face:"Menlo",color:p.ink.withAlphaComponent(0.45))
            }
        }
        if let url = historyURL {
            // Save identifiers only, under a separate short-lived display lock.
            // Preview/test scenes never receive a writable history URL.
            try? FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            if let lock = try? CommonplaceGenerationLease(url:url.deletingLastPathComponent().appendingPathComponent("display.lock")) {
                defer { withExtendedLifetime(lock) {} }
                if let other = Self.readHistory(url) {
                    func merged<T:Equatable>(_ old:[T],_ new:[T],_ limit:Int)->[T] { Array((old.filter { !new.contains($0) }+new).suffix(limit)) }
                    selection.recentEntries = merged(other.recentEntries,selection.recentEntries,30)
                    selection.recentArtifacts = merged(other.recentArtifacts,selection.recentArtifacts,6)
                    selection.recentLayouts = merged(other.recentLayouts,selection.recentLayouts,8)
                    selection.recentPairs = merged(other.recentPairs,selection.recentPairs,60)
                }
                try? JSONEncoder().encode(selection).write(to:url,options:.atomic)
            }
        }
        return c.makeImage()
    }
    private func studyVariant(_ entries:[CommonplaceEntry])->Int {
        let text = (entries.first?.text ?? "").lowercased()
        if ["leaf","fern","seed","plant"].contains(where:text.contains) { return 1 }
        if text.contains("gear") { return 5 }
        if text.contains("hinge") { return 6 }
        if ["shelf","bracket","drawer"].contains(where:text.contains) { return 4 }
        if ["paper","boat","fold"].contains(where:text.contains) { return 2 }
        if ["rain","water","cup","kettle"].contains(where:text.contains) { return 0 }
        return 3
    }
    private func diagram(_ c:CGContext,rect:CGRect,variant:Int,color:NSColor) {
        c.saveGState();c.translateBy(x:rect.midX,y:rect.midY);c.setStrokeColor(color.withAlphaComponent(0.58).cgColor);c.setLineWidth(1)
        let r = min(rect.width,rect.height)*0.36
        switch variant%8 {
        case 0: // A small jar study, not a scientific or historical claim.
            c.move(to:CGPoint(x:-r*0.5,y:r));c.addLine(to:CGPoint(x:-r*0.55,y:-r));c.addQuadCurve(to:CGPoint(x:r*0.55,y:-r),control:CGPoint(x:0,y:-r*1.1));c.addLine(to:CGPoint(x:r*0.5,y:r));c.strokePath()
            c.strokeEllipse(in:CGRect(x:-r*0.52,y:r-8,width:r*1.04,height:16))
            for i in 0..<5 { let y = -r+Double(i)*r*0.35;c.move(to:CGPoint(x:r*0.65,y:y));c.addLine(to:CGPoint(x:r*0.85,y:y));c.strokePath() }
        case 1: // Leaf venation, drawn separately from verified archival material.
            c.move(to:CGPoint(x:0,y:-r));c.addQuadCurve(to:CGPoint(x:0,y:r),control:CGPoint(x:r*0.12,y:0));c.strokePath()
            for side in [-1.0,1.0] { c.move(to:CGPoint(x:0,y:-r));c.addCurve(to:CGPoint(x:0,y:r),control1:CGPoint(x:side*r*(side<0 ? 0.82:1.05),y:-r*0.6),control2:CGPoint(x:side*r*(side<0 ? 0.7:0.48),y:r*0.5));c.strokePath()
                for i in 0..<7 { let y = -r*0.75+Double(i)*r*0.23+(side<0 ? r*0.035:0);c.move(to:CGPoint(x:0,y:y));c.addQuadCurve(to:CGPoint(x:side*r*(0.5-abs(y/r)*0.3),y:y+r*0.3),control:CGPoint(x:side*r*0.3,y:y+r*0.2));c.strokePath() }
            }
        case 2: // Folded paper and construction lines.
            c.move(to:CGPoint(x:-r,y:-r*0.6));c.addLine(to:CGPoint(x:r,y:-r*0.4));c.addLine(to:CGPoint(x:r*0.7,y:r*0.7));c.addLine(to:CGPoint(x:-r*0.8,y:r*0.8));c.closePath();c.strokePath()
            c.setLineDash(phase:0,lengths:[4,5]);c.move(to:CGPoint(x:-r,y:-r*0.6));c.addLine(to:CGPoint(x:r*0.7,y:r*0.7));c.strokePath()
        case 3: // An observed, deliberately imperfect loop of string.
            c.move(to:CGPoint(x:-r*0.7,y:-r*0.4));c.addCurve(to:CGPoint(x:r*0.2,y:r*0.6),control1:CGPoint(x:-r*1.2,y:r),control2:CGPoint(x:r,y:r));c.addCurve(to:CGPoint(x:r*0.8,y:-r*0.7),control1:CGPoint(x:-r,y:-r),control2:CGPoint(x:r*1.3,y:-r*0.2));c.strokePath()
        case 5: // Gear: observational study, not an invented patent.
            let path = CGMutablePath()
            for i in 0..<64 { let a = Double(i)*Double.pi/32, radius = i%4<2 ? r:r*0.86;let point = CGPoint(x:cos(a)*radius,y:sin(a)*radius);if i == 0 { path.move(to:point) } else { path.addLine(to:point) } }
            path.closeSubpath();c.addPath(path);c.strokePath();c.strokeEllipse(in:CGRect(x:-r*0.22,y:-r*0.22,width:r*0.44,height:r*0.44))
            for angle in [0.0,2.1,4.2] { c.move(to:CGPoint(x:cos(angle)*r*0.3,y:sin(angle)*r*0.3));c.addLine(to:CGPoint(x:cos(angle)*r*0.73,y:sin(angle)*r*0.73));c.strokePath() }
        case 6: // Hinge with a pin and paired leaves.
            c.stroke(CGRect(x:-r,y:-r*0.7,width:r*0.87,height:r*1.4));c.stroke(CGRect(x:r*0.13,y:-r*0.7,width:r*0.87,height:r*1.4))
            c.stroke(CGRect(x:-r*0.10,y:-r*0.8,width:r*0.20,height:r*1.6))
            for x in [-r*0.60,r*0.60] { for y in [-r*0.42,r*0.42] { c.strokeEllipse(in:CGRect(x:x-4,y:y-4,width:8,height:8)) } }
        case 7: // An original sky sketch, explicitly not a historical star chart.
            for i in 1...3 { let radius = r*Double(i)/3;c.strokeEllipse(in:CGRect(x:-radius,y:-radius,width:radius*2,height:radius*2)) }
            c.setLineDash(phase:0,lengths:[2,7]);c.move(to:CGPoint(x:-r*1.15,y:-r*0.55));c.addQuadCurve(to:CGPoint(x:r*1.15,y:-r*0.50),control:CGPoint(x:0,y:-r*0.75));c.strokePath();c.setLineDash(phase:0,lengths:[])
            var random = ArtRandom(state:seed &+ UInt64(pageNumber+2))
            for _ in 0..<28 { let x = (random.next()-0.5)*r*1.8,y = (random.next()-0.5)*r*1.8;c.setFillColor(color.withAlphaComponent(0.45+random.next()*0.35).cgColor);c.fillEllipse(in:CGRect(x:x,y:y,width:1.8,height:1.8)) }
        default: // Shelf / bracket study.
            for offset in [0.0,7.0] { c.stroke(CGRect(x:-r,y:r*0.2+offset,width:r*2,height:r*0.08)) }
            for x in [-r*0.65,r*0.65] { c.move(to:CGPoint(x:x,y:r*0.2));c.addLine(to:CGPoint(x:x,y:-r*0.6));c.addLine(to:CGPoint(x:x+r*0.38,y:r*0.2));c.strokePath() }
        }
        if variant == 7 {
            c.setLineWidth(0.5);c.move(to:CGPoint(x:-r*0.6,y:r*0.1));c.addQuadCurve(to:CGPoint(x:r*0.45,y:r*0.48),control:CGPoint(x:-r*0.1,y:r*0.68));c.strokePath()
            for i in 0..<9 { let angle = Double(i)*0.16+0.3;c.move(to:CGPoint(x:cos(angle)*r*1.04,y:sin(angle)*r*1.04));c.addLine(to:CGPoint(x:cos(angle)*r*1.09,y:sin(angle)*r*1.09));c.strokePath() }
            withAppKit(c) { lettering("thin cloud, then clear",rect:CGRect(x:-r*0.8,y:r*1.13,width:r*1.8,height:26),size:12,face:"Noteworthy-Light",color:color.withAlphaComponent(0.75)) }
        } else if variant == 1 {
            c.setLineWidth(0.45);c.setLineDash(phase:0,lengths:[2,5]);c.move(to:CGPoint(x:-r*0.72,y:-r*1.08));c.addLine(to:CGPoint(x:r*0.8,y:-r*1.08));c.strokePath()
            withAppKit(c) { lettering("edge study / unmeasured",rect:CGRect(x:-r*0.85,y:-r*1.3,width:r*2,height:24),size:11,face:"Baskerville-Italic",color:color.withAlphaComponent(0.65)) }
        }
        c.restoreGState()
    }
    func updateLayer(_ root:CALayer,size:CGSize,time:Double,date:Date)->Bool {
        guard size.width>0,size.height>0,size.width.isFinite,size.height.isFinite else { return true }
        if running { clock.step(now:time,speed:1,maximumStep:0.25) }
        if library == nil { library = CommonplaceLibrary(archive:archive,resources:resources) }
        CATransaction.begin();CATransaction.setDisableActions(true);defer { CATransaction.commit() }
        let number = Int(clock.elapsed/settings.pace.secondsPerPage), theme = Int(clock.elapsed/1500)
        let sheetSize = CGSize(width:min(size.width*0.96,size.height*1.65),height:size.height*0.96)
        let themeChanged = theme != themeNumber
        if themeChanged || rebuild {
            currentTheme = settings.theme == .automatic ? Array(CommonplaceTheme.allCases.dropFirst())[(theme+Int(seed%6))%6]:settings.theme;themeNumber = theme
        }
        if desk.superlayer !== root { root.addSublayer(desk);root.addSublayer(departing);root.addSublayer(page);root.masksToBounds = true }
        let camera = CommonplaceDesk.camera(seconds:clock.elapsed,size:size)
        if size != lastSize || rebuild || themeChanged || desk.contents == nil {
            desk.contents = CommonplaceDesk.image(size:size,desk:colors.desk,paper:colors.paper,ink:colors.ink,seed:seed)
        }
        desk.bounds = CGRect(x:0,y:0,width:size.width*1.16,height:size.height*1.16)
        desk.position = CGPoint(x:size.width/2+camera.x,y:size.height/2+camera.y)
        if number != pageNumber || size != lastSize || rebuild {
            if number != pageNumber { library = CommonplaceLibrary(archive:archive,resources:resources) }
            departing.contents = page.contents;departing.setAffineTransform(page.affineTransform());departing.bounds = CGRect(origin:.zero,size:sheetSize);departing.position = CGPoint(x:size.width/2,y:size.height/2)
            page.contents = makePage(size:sheetSize,number:number);pageNumber = number;lastSize = size;rebuild = false
        }
        var motion = ArtRandom(state:seed &+ UInt64(number)*17_171)
        let direction = motion.next(), duration = 3.5+motion.next()*1.5
        let phase = clock.elapsed.truncatingRemainder(dividingBy:settings.pace.secondsPerPage), p = min(1,phase/duration), eased = p*p*(3-2*p)
        let progress = number == 0 ? 0:1-eased
        let slideX = direction<0.34 ? -progress*size.width:direction<0.76 ? progress*size.width:progress*size.width*0.08
        let slideY = direction>=0.76 ? progress*size.height:0
        page.bounds = CGRect(origin:.zero,size:sheetSize)
        page.position = CGPoint(x:size.width/2+camera.x+slideX,y:size.height/2+camera.y+slideY)
        page.setAffineTransform(CGAffineTransform(rotationAngle:0.008*sin(Double(number)*2.4+Double(seed%9))))
        // The previous sheet stays opaque as a shallow stack under the new one.
        // Only the arriving page slides; desk fibers never ghost through paper.
        departing.position = CGPoint(x:size.width/2+camera.x-eased*4,y:size.height/2+camera.y-eased*5)
        departing.opacity = number>0 ? 1:0
        page.shadowOpacity = number>0 && p<1 ? 0.25:0;page.shadowRadius = 20
        return true
    }
    func draw(in context:CGContext,size:CGSize,time:Double,date:Date) { let layer = CALayer();layer.bounds = CGRect(origin:.zero,size:size);_ = updateLayer(layer,size:size,time:time,date:date);layer.render(in:context) }
}
