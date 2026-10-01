import AppKit
import QuartzCore

func bitmap(width: Int, height: Int) -> CGContext? {
    guard width > 0, height > 0, width <= 4096, height <= 4096 else { return nil }
    return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                     space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
}
func text(_ string: String, at point: CGPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular, tracking: CGFloat = 0) {
    (string as NSString).draw(at: point, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .kern: tracking])
}
func withAppKit(_ context: CGContext, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    draw()
    NSGraphicsContext.restoreGraphicsState()
}
func line(_ context: CGContext, from: CGPoint, to: CGPoint, width: CGFloat, color: CGColor) {
    context.setStrokeColor(color); context.setLineWidth(width)
    context.move(to: from); context.addLine(to: to); context.strokePath()
}

protocol SaverScene: AnyObject {
    func start()
    func stop()
    func apply(_ settings: SaverSettings)
    func updateLayer(_ layer: CALayer, size: CGSize, time: Double, date: Date) -> Bool
    func draw(in context: CGContext, size: CGSize, time: Double, date: Date)
}

extension SaverScene {
    func updateLayer(_ layer: CALayer, size: CGSize, time: Double, date: Date) -> Bool { false }
}
