import AppKit

// Best-effort legacy picker resources. Current System Settings may ignore them;
// there is no supported ScreenSaver API for replacing its default thumbnail.
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let folder = URL(fileURLWithPath: CommandLine.arguments[2])
guard let image = NSImage(contentsOf: source) else { fatalError("Missing preview image: \(source)") }
var reps: [NSBitmapImageRep] = []
for scale in [1, 2] {
    let width = 90 * scale, height = 58 * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ratio = max(CGFloat(width) / image.size.width, CGFloat(height) / image.size.height)
    let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
    image.draw(in: CGRect(x: (CGFloat(width) - size.width) / 2, y: (CGFloat(height) - size.height) / 2,
                          width: size.width, height: size.height))
    NSGraphicsContext.restoreGraphicsState()
    rep.size = NSSize(width: 90, height: 58)
    let filename = scale == 1 ? "thumbnail.png" : "thumbnail@2x.png"
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(filename))
    reps.append(rep)
}
try NSBitmapImageRep.representationOfImageReps(in: reps, using: .tiff, properties: [:])!
    .write(to: folder.appendingPathComponent("thumbnail.tiff"))
