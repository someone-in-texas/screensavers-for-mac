import AppKit
import CoreText

/// Bundled OFL font, process-local only. Variation belongs to a passage, so a
/// repaint, resize or pause never reshuffles its handwriting.
enum CommonplaceHandwriting {
    static let face = "Kalam-Regular"
    private static var registered = Set<String>()
    static func register(resources: URL?) {
        let directory = resources ?? Bundle(for:CommonplaceScene.self).resourceURL?.appendingPathComponent("Commonplace")
        guard let url = directory?.appendingPathComponent("Fonts/Kalam-Regular.ttf"), !registered.contains(url.path) else { return }
        if CTFontManagerRegisterFontsForURL(url as CFURL,.process,nil) || NSFont(name:face,size:20) != nil { registered.insert(url.path) }
    }
    static func attributes(_ string: String, size: CGFloat, color: NSColor) -> NSAttributedString {
        let font = NSFont(name:face,size:size) ?? NSFont(name:"Noteworthy-Light",size:size) ?? NSFont.systemFont(ofSize:size)
        let style = NSMutableParagraphStyle();style.lineSpacing = size*0.12;style.lineBreakMode = .byWordWrapping
        let result = NSMutableAttributedString(string:string,attributes:[.font:font,.foregroundColor:color,.paragraphStyle:style])
        let words = string as NSString
        var start = 0, word = 0
        for i in 0...words.length {
            if i == words.length || words.character(at:i) == 32 || words.character(at:i) == 10 {
                if i>start {
                    let kern = size*0.006*sin(Double(word)*1.71+Double(string.utf8.count)*0.19)
                    result.addAttribute(.kern,value:kern,range:NSRange(location:start,length:i-start));word += 1
                };start = i+1
            }
        }
        return result
    }
    static func height(_ string: String, width: CGFloat, size: CGFloat) -> CGFloat {
        let setter = CTFramesetterCreateWithAttributedString(attributes(string,size:size,color:.black))
        let measured = CTFramesetterSuggestFrameSizeWithConstraints(setter,CFRange(),nil,CGSize(width:max(1,width-6),height:10000),nil)
        return ceil(measured.height)+8
    }
    static func draw(_ string: String, rect: CGRect, size: CGFloat, color: NSColor) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        let setter = CTFramesetterCreateWithAttributedString(attributes(string,size:size,color:color))
        let path = CGPath(rect:rect.insetBy(dx:3,dy:3),transform:nil)
        let frame = CTFramesetterCreateFrame(setter,CFRange(),path,nil)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        guard !lines.isEmpty else { return }
        var origins = Array(repeating:CGPoint.zero,count:lines.count)
        CTFrameGetLineOrigins(frame,CFRange(),&origins)
        for (index,line) in lines.enumerated() {
            let phase = Double(index)*1.63+Double(string.utf8.count)*0.071
            c.saveGState();c.textMatrix = .identity
            c.translateBy(x:rect.minX+3+origins[index].x+sin(phase)*size*0.035,y:rect.minY+3+origins[index].y+sin(phase*0.63)*size*0.027)
            c.rotate(by:sin(phase)*0.0025);c.textPosition = .zero
            CTLineDraw(line,c);c.restoreGState()
        }
    }
}
