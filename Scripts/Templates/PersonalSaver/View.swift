import AppKit
import ScreenSaver

@objc(__CLASS__View)
final class __CLASS__View: ScreenSaverView {
    private let scene = PersonalScene()
    @objc(initWithFrame:isPreview:)
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30
        autoresizingMask = [.width, .height]
    }
    required init?(coder: NSCoder) { nil }
    override var isOpaque: Bool { true }
    override func startAnimation() { scene.start(); super.startAnimation() }
    override func stopAnimation() { scene.stop(); super.stopAnimation() }
    override func animateOneFrame() { needsDisplay = true }
    override func draw(_ rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let viewport = visibleRect.intersection(bounds)
        guard viewport.width > 0, viewport.height > 0 else { return }
        context.saveGState(); context.translateBy(x: viewport.minX, y: viewport.minY)
        scene.draw(in: context, size: viewport.size, time: ProcessInfo.processInfo.systemUptime)
        context.restoreGState()
    }
}
