// Compile/run with `swift Scripts/bloom-contact-sheet.swift build/bloom-art/final`.
// This only arranges actual PreviewHost output; it never synthesizes artwork.
import AppKit
let directory = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("--") }) ?? "build/bloom-art/final"
let refinement = CommandLine.arguments.contains("--refinement")
let rows = refinement ? [("Grouped meadow", "meadow/oak-3.38.png"),
                         ("Branch and pigment detail", "detail/oak-3.35.png"),
                         ("Rain / autumn", "oak/oak-3.6.png"),
                         ("Snow / winter", "oak/oak-3.86.png"),
                         ("Woodland", "woodland/oak-3.35.png"),
                         ("Young seedling", "oak/oak-0.2.png"),
                         ("Delicate flowers", "lavender/lavender-3.35.png")] : [("Mature broadleaf", "oak/oak-3.35.png"),
            ("Delicate flowers", "lavender/lavender-3.35.png"),
            ("Young seedling", "oak/oak-0.2.png"),
            ("Woody structure / winter", "oak/oak-3.86.png"),
            ("Fading foliage", "maple/maple-3.66.png"),
            ("Mixed meadow", "meadow/oak-3.38.png"),
            ("3x renderer close-up", "detail/oak-3.35.png")]
let styles = refinement ? [("Before refinement","before"),("First art-critic revision","round1"),("Final refinement","final")] : [("A — Original / Classic","classic"),("B — Organic","organic"),("C — Botanical Watercolor","botanicalWatercolor")]
let width = 1800, height = rows.count*458+60
let context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(NSColor(srgbRed:0.98,green:0.97,blue:0.94,alpha:1).cgColor)
context.fill(CGRect(x:0,y:0,width:width,height:height))
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current = NSGraphicsContext(cgContext:context,flipped:false)
for (column,style) in styles.enumerated() {
    (style.0 as NSString).draw(at:CGPoint(x:column*600+18,y:height-40),withAttributes:[.font:NSFont.systemFont(ofSize:21,weight:.medium),.foregroundColor:NSColor.darkGray])
    for (row,sample) in rows.enumerated() {
        let path = directory+"/"+style.1+"/"+sample.1
        guard let image = NSImage(contentsOfFile:path)?.cgImage(forProposedRect:nil,context:nil,hints:nil) else { fatalError("Missing capture: \(path)") }
        let y = height-60-(row+1)*458
        context.draw(image,in:CGRect(x:column*600,y:y+4,width:600,height:428))
        (sample.0 as NSString).draw(at:CGPoint(x:column*600+18,y:y+433),withAttributes:[.font:NSFont.systemFont(ofSize:15),.foregroundColor:NSColor.darkGray])
    }
}
NSGraphicsContext.restoreGraphicsState()
let bitmap = NSBitmapImageRep(cgImage:context.makeImage()!)
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:directory+"/comparison.png"))
print(directory+"/comparison.png")
