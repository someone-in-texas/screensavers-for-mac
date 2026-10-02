import AppKit
import ScreenSaver

class SceneSaverView: ScreenSaverView {
    let scene: SaverScene
    let store: SettingsStore
    private var configuration: ConfigurationController?
    private var buffer: CGContext?
    private var bufferSize = CGSize.zero
    init?(frame: NSRect, isPreview: Bool, kind: SaverKind, scene: SaverScene? = nil, settingsStore: SettingsStore? = nil) {
        store = settingsStore ?? SettingsStore(kind)
        if let scene { self.scene = scene }
        else {
            switch kind {
            case .worldClockRoom: self.scene = WorldClockScene()
            case .cityDrift: self.scene = CityDriftScene(store: store)
            case .voxelCosmos: self.scene = VoxelCosmosScene()
            case .paperSky: self.scene = PaperSkyScene()
            case .dapple: self.scene = DappleScene()
            case .flourish: self.scene = FlourishScene()
            case .lattice: self.scene = LatticeScene()
            }
        }
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        animationTimeInterval = 1.0 / (kind == .cityDrift || kind == .paperSky ? 60 : 30)
        self.scene.apply(store.value)
        autoresizingMask = [.width, .height]
    }
    required init?(coder: NSCoder) { nil }
    override var isOpaque: Bool { true }
    override func startAnimation() { scene.apply(store.value); scene.start(); super.startAnimation() }
    override func stopAnimation() { scene.stop(); super.stopAnimation() }
    override func animateOneFrame() {
        if !presentLayers() { needsDisplay = true }
    }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        if !presentLayers() { needsDisplay = true }
    }
    override func layout() { super.layout(); if !presentLayers() { needsDisplay = true } }
    private func presentLayers() -> Bool {
        guard bounds.width > 0, bounds.height > 0, let layer else { return false }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.contentsScale = window?.backingScaleFactor ?? 1
        let presented = scene.updateLayer(layer, size: bounds.size, time: ProcessInfo.processInfo.systemUptime, date: Date())
        CATransaction.commit()
        return presented
    }
    override func draw(_ rect: NSRect) {
        if presentLayers() { return }
        guard bounds.width > 0, bounds.height > 0, let target = NSGraphicsContext.current?.cgContext else { return }
        let size = Mercator.renderSize(bounds.size)
        let pixels = CGSize(width: ceil(size.width), height: ceil(size.height))
        if buffer == nil || bufferSize != pixels {
            buffer = bitmap(width: Int(pixels.width), height: Int(pixels.height)); bufferSize = pixels
        }
        guard let buffer else { return }
        scene.draw(in: buffer, size: pixels, time: ProcessInfo.processInfo.systemUptime, date: Date())
        if let image = buffer.makeImage() { target.interpolationQuality = .high; target.draw(image, in: bounds) }
    }
    override var hasConfigureSheet: Bool { true }
    override var configureSheet: NSWindow? {
        // Hosts may query this property repeatedly before/during presentation.
        // Replacing a live controller leaves a stale sheet/modal session behind.
        if configuration == nil {
            configuration = ConfigurationController(store: store) { [weak self] settings in
                self?.scene.apply(settings); self?.needsDisplay = true
            }
        }
        configuration?.prepareForPresentation()
        return configuration?.window
    }
    deinit { scene.stop() }
}
