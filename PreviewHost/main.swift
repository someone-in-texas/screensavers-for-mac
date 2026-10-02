import AppKit
import ScreenSaver

func fixtureTile() -> CGImage {
    let c = bitmap(width: 256, height: 256)!
    c.setFillColor(NSColor(srgbRed: 0.92, green: 0.90, blue: 0.85, alpha: 1).cgColor); c.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
    for i in stride(from: 0, through: 256, by: 32) {
        line(c, from: CGPoint(x: i, y: 0), to: CGPoint(x: i, y: 256), width: 5, color: NSColor.white.cgColor)
        line(c, from: CGPoint(x: 0, y: i), to: CGPoint(x: 256, y: i), width: 4, color: NSColor.white.cgColor)
    }
    line(c, from: CGPoint(x: 0, y: 10), to: CGPoint(x: 256, y: 240), width: 9, color: NSColor.gray.cgColor)
    return c.makeImage()!
}
func savePNG(_ image: CGImage, _ path: String) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

final class PreviewSaverView: SceneSaverView {
    private(set) var animationFrames = 0
    private let profile = CommandLine.arguments.contains("--profile")
    private var frameTimes: [Double] = []
    override func animateOneFrame() {
        animationFrames += 1
        let start = profile ? ProcessInfo.processInfo.systemUptime : 0
        super.animateOneFrame()
        if profile && frameTimes.count < 6000 { frameTimes.append((ProcessInfo.processInfo.systemUptime-start)*1000) }
    }
    func reportPerformance() {
        guard !frameTimes.isEmpty else { return }
        let sorted = frameTimes.sorted()
        print("\(store.kind.title): \(animationFrames) frames; render p50 \(sorted[sorted.count/2]) ms, p95 \(sorted[Int(Double(sorted.count-1)*0.95)]) ms, max \(sorted.last!) ms")
    }
}

final class PreviewDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var view: PreviewSaverView?
    let picker = NSPopUpButton()
    private let smokeSuite = "screensavers.launch-smoke.\(UUID().uuidString)"
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Screensavers for Mac — Preview"
        window.minSize = NSSize(width: 640, height: 240)
        window.center()
        picker.addItems(withTitles: SaverKind.allCases.map(\.title)); picker.target = self; picker.action = #selector(switchScene)
        picker.frame = NSRect(x: 18, y: 752, width: 190, height: 28); picker.autoresizingMask = [.minYMargin]
        let configure = NSButton(title: "Configure…", target: self, action: #selector(configure))
        configure.bezelStyle = .rounded; configure.frame = NSRect(x: 220, y: 752, width: 120, height: 28); configure.autoresizingMask = [.minYMargin]
        let full = NSButton(title: "Full Screen", target: self, action: #selector(fullScreen))
        full.bezelStyle = .rounded; full.frame = NSRect(x: 348, y: 752, width: 120, height: 28); full.autoresizingMask = [.minYMargin]
        let save = NSButton(title: "Save Frame…", target: self, action: #selector(saveFrame))
        save.bezelStyle = .rounded; save.frame = NSRect(x: 476, y: 752, width: 130, height: 28); save.autoresizingMask = [.minYMargin]
        window.contentView?.addSubview(save)
        window.contentView?.addSubview(picker); window.contentView?.addSubview(configure); window.contentView?.addSubview(full)
        let menu = NSMenu(); let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit PreviewHost", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); appItem.submenu = appMenu
        NSApp.mainMenu = menu
        if CommandLine.arguments.contains("--map") { picker.selectItem(at: 1) }
        if CommandLine.arguments.contains("--cosmos") || CommandLine.arguments.contains("--cosmos-review") { picker.selectItem(at: 2) }
        switchScene(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if let i = CommandLine.arguments.firstIndex(of: "--capture-after"), i + 1 < CommandLine.arguments.count,
           let seconds = Double(CommandLine.arguments[i + 1]), seconds.isFinite {
            DispatchQueue.main.asyncAfter(deadline: .now() + min(60, max(1, seconds))) {
                self.saveFrame()
                if CommandLine.arguments.contains("--capture-and-quit") { self.view?.stopAnimation(); NSApp.terminate(nil) }
            }
        }
        if CommandLine.arguments.contains("--launch-smoke") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.checkConfigurationCycle(0) }
        }
    }
    private func checkConfigurationCycle(_ index: Int) {
        if index == 0 || index % 6 == 5 { precondition((view?.animationFrames ?? 0) > 5, "Preview host must drive real animation frames for every saver") }
        if index == 18 { print("Passed 18 configuration open/Done/reopen cycles across all three savers."); view?.stopAnimation(); NSApp.terminate(nil); return }
        if index > 0 && index % 6 == 0 { picker.selectItem(at: index / 6); switchScene() }
        guard let sheet = view?.configureSheet else { fatalError("Missing configuration sheet") }
        precondition(view?.configureSheet === sheet, "Host property queries must return the same window")
        window.beginSheet(sheet)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            precondition(self.view?.configureSheet === sheet && sheet.sheetParent === self.window, "Live sheet cannot be replaced")
            let done = sheet.contentView?.subviews.compactMap { $0 as? NSButton }.first { $0.title == "Done" }
            precondition(done != nil)
            done?.performClick(nil) // Exercise our dismissal handler, not a host-side shortcut.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                precondition(sheet.sheetParent == nil && !sheet.isVisible, "Done must detach and hide the sheet")
                precondition(self.view?.configureSheet === sheet, "Reopening reuses the retained window")
                self.checkConfigurationCycle(index + 1)
            }
        }
    }
    @objc func switchScene() {
        view?.reportPerformance(); view?.stopAnimation(); view?.removeFromSuperview()
        let kind = SaverKind.allCases[picker.indexOfSelectedItem]
        let review = CommandLine.arguments.contains("--online-vector") || CommandLine.arguments.contains("--cosmos-review")
        let store = SettingsStore(kind, defaults: (CommandLine.arguments.contains("--launch-smoke") || review) ? UserDefaults(suiteName: smokeSuite + kind.rawValue) : nil)
        if review {
            var settings = SaverSettings(); settings.cosmos.secondsPerView = 15; settings.mapStyle = .online; settings.palette = .blueprint
            if CommandLine.arguments.contains("--details") { settings.streetLabels = true; settings.water = true; settings.parks = true; settings.pointsOfInterest = true }
            store.value = settings
        }
        let noNetwork = CommandLine.arguments.contains("--offline") || CommandLine.arguments.contains("--launch-smoke")
        let fixed = CommandLine.arguments.firstIndex(of: "--city").flatMap { i in i + 1 < CommandLine.arguments.count ? CommandLine.arguments[i + 1] : nil }
        let scene: SaverScene = kind == .worldClockRoom ? WorldClockScene() : kind == .voxelCosmos ? VoxelCosmosScene() as SaverScene : CityDriftScene(store: store, networkEnabled: !noNetwork, city: MapCity.all.first { $0.name == fixed }, visitCache: noNetwork && !CommandLine.arguments.contains("--launch-smoke") ? CityVisitCache() : nil)
        let frame = NSRect(x: 0, y: 0, width: window.contentView!.bounds.width, height: window.contentView!.bounds.height - 48)
        view = PreviewSaverView(frame: frame, isPreview: false, kind: kind, scene: scene, settingsStore: store)
        window.contentView?.addSubview(view!, positioned: .below, relativeTo: picker)
        view?.startAnimation()
    }
    @objc func configure() { if window.attachedSheet == nil, let sheet = view?.configureSheet { window.beginSheet(sheet) } }
    @objc func saveFrame() {
        guard let view, let layer = view.layer else { return }
        let size = Mercator.mapRenderSize(view.bounds.size, backingScale: window.backingScaleFactor)
        guard let c = bitmap(width: Int(size.width), height: Int(size.height)) else { return }
        c.scaleBy(x: size.width / view.bounds.width, y: size.height / view.bounds.height)
        layer.render(in: c)
        guard let image = c.makeImage() else { return }
        let filename = ["world-clock-room.png", "city-drift.png", "voxel-cosmos.png"][picker.indexOfSelectedItem]
        if let i = CommandLine.arguments.firstIndex(of: "--capture-dir"), i + 1 < CommandLine.arguments.count {
            let directory = CommandLine.arguments[i + 1]
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try? savePNG(image, "\(directory)/\(filename)")
        } else {
            let panel = NSSavePanel(); panel.nameFieldStringValue = filename; panel.allowedContentTypes = [.png]
            panel.beginSheetModal(for: window) { result in
                if result == .OK, let url = panel.url { try? savePNG(image, url.path) }
            }
        }
    }
    @objc func fullScreen() { window.toggleFullScreen(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        view?.reportPerformance(); view?.stopAnimation()
        if CommandLine.arguments.contains("--launch-smoke") || CommandLine.arguments.contains("--online-vector") || CommandLine.arguments.contains("--cosmos-review") {
            for kind in SaverKind.allCases { UserDefaults.standard.removePersistentDomain(forName: smokeSuite + kind.rawValue) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
if CommandLine.arguments.contains("--smoke") {
    let folder = CommandLine.arguments.firstIndex(of: "--output").flatMap { i in i + 1 < CommandLine.arguments.count ? CommandLine.arguments[i + 1] : nil } ?? "build/smoke"
    try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
    let suiteName = "screensavers.smoke.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = SettingsStore(.cityDrift, defaults: defaults)
    let map = CityDriftScene(store: store, networkEnabled: false, city: MapCity.all[0]); map.useFixture(fixtureTile())
    let clock = WorldClockScene()
    let sizes = [CGSize(width: 1600, height: 1000), CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1080), CGSize(width: 280, height: 180), CGSize(width: 800, height: 1200)]
    for (name, scene) in [("world-clock-room", clock as SaverScene), ("city-drift-fixture", map as SaverScene), ("voxel-cosmos", VoxelCosmosScene() as SaverScene)] {
        scene.start()
        for size in sizes {
            let c = bitmap(width: Int(size.width), height: Int(size.height))!
            scene.apply(SaverSettings())
            scene.draw(in: c, size: size, time: 100, date: Date(timeIntervalSince1970: 1780315800))
            scene.draw(in: c, size: size, time: 102, date: Date(timeIntervalSince1970: 1780315802))
            try savePNG(c.makeImage()!, "\(folder)/\(name)-\(Int(size.width))x\(Int(size.height)).png")
            let root = CALayer(); root.bounds = CGRect(origin: .zero, size: size)
            CATransaction.begin(); CATransaction.setDisableActions(true)
            precondition(scene.updateLayer(root, size: size, time: 103, date: Date(timeIntervalSince1970: 1780315802)))
            CATransaction.commit()
            c.clear(CGRect(origin: .zero, size: size)); root.render(in: c)
            try savePNG(c.makeImage()!, "\(folder)/\(name)-layers-\(Int(size.width))x\(Int(size.height)).png")
        }
        var paletteTime = 200.0
        for palette in MapPalette.allCases {
            paletteTime += 5
            var settings = SaverSettings(); settings.palette = palette; settings.grain = true; settings.intensity = 1
            scene.apply(settings)
            let c = bitmap(width: 800, height: 500)!
            scene.draw(in: c, size: CGSize(width: 800, height: 500), time: paletteTime, date: Date())
            scene.draw(in: c, size: CGSize(width: 800, height: 500), time: paletteTime + 2, date: Date())
            if name == "city-drift-fixture" { try savePNG(c.makeImage()!, "\(folder)/palette-\(palette.rawValue).png") }
        }
        scene.stop()
    }
    for view in CosmosView.allCases {
        let scene = VoxelCosmosScene(); var settings = SaverSettings(); settings.cosmos.view = view
        scene.apply(settings); scene.start()
        let size = CGSize(width: 1200, height: 800), c = bitmap(width: 1200, height: 800)!
        scene.draw(in: c, size: size, time: 0, date: Date())
        try savePNG(c.makeImage()!, "\(folder)/cosmos-\(view.rawValue).png")
        scene.stop()
    }
    for angle in CosmosAngle.allCases {
        let scene = VoxelCosmosScene(); var settings = SaverSettings()
        settings.cosmos.view = .saturn; settings.cosmos.angle = angle
        settings.cosmos.glow = 1; settings.cosmos.pixelSize = angle == .high ? 5 : 2
        scene.apply(settings); scene.start()
        let size = CGSize(width: 1920, height: 1080), c = bitmap(width: 1920, height: 1080)!
        scene.draw(in: c, size: size, time: 0, date: Date())
        try savePNG(c.makeImage()!, "\(folder)/cosmos-angle-\(angle.rawValue).png")
        scene.stop()
    }
    for background in CosmosBackground.allCases {
        let scene = VoxelCosmosScene(); var settings = SaverSettings()
        settings.cosmos.view = .saturn; settings.cosmos.background = background; settings.cosmos.angle = .low
        scene.apply(settings); scene.start()
        let size = CGSize(width: 800, height: 1200), c = bitmap(width: 800, height: 1200)!
        scene.draw(in: c, size: size, time: 0, date: Date())
        try savePNG(c.makeImage()!, "\(folder)/cosmos-background-\(background.rawValue).png")
        scene.stop()
    }
    precondition(StarterMaps.bundled.cities.count == 3, "Bundled starter maps missing")
    for city in StarterMaps.bundled.catalog {
        let starter = CityDriftScene(store: store, networkEnabled: false, city: city)
        starter.start()
        var settings = SaverSettings(); settings.palette = .blueprint; settings.mapStyle = .lines
        starter.apply(settings)
        let c = bitmap(width: 1600, height: 1000)!
        starter.draw(in: c, size: CGSize(width: 1600, height: 1000), time: 0, date: Date())
        try savePNG(c.makeImage()!, "\(folder)/starter-\(city.name.lowercased()).png")
        if city.name == "Paris" {
            settings.palette = .paper; starter.apply(settings)
            starter.draw(in: c, size: CGSize(width: 1600, height: 1000), time: 0, date: Date())
            try savePNG(c.makeImage()!, "\(folder)/line-paris-paper.png")
            settings.palette = .blueprint
        }
        settings.streetLabels = true; settings.water = true; settings.parks = true; settings.pointsOfInterest = true
        starter.apply(settings)
        starter.draw(in: c, size: CGSize(width: 1600, height: 1000), time: 1, date: Date())
        try savePNG(c.makeImage()!, "\(folder)/details-\(city.name.lowercased()).png")
        starter.stop()
    }
    for kind in SaverKind.allCases {
        let panel = ConfigurationController(store: SettingsStore(kind, defaults: defaults)) { _ in }
        if let content = panel.window?.contentView, let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
            content.cacheDisplay(in: content.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(folder)/options-\(kind.rawValue).png"))
        }
    }
    // Load the actual bundles and invoke their principal classes, not just the shared scenes.
    let products = Bundle.main.bundleURL.deletingLastPathComponent()
    for name in ["World Clock Room", "City Drift", "Voxel Cosmos"] {
        guard let bundle = Bundle(url: products.appendingPathComponent("\(name).saver")),
              let type = bundle.principalClass as? ScreenSaverView.Type,
              let view = type.init(frame: NSRect(x: 0, y: 0, width: 300, height: 200), isPreview: true),
              view.hasConfigureSheet, view.configureSheet != nil else { fatalError("Bundle load failed: \(name)") }
        // Start/stop the clock; map scene smoke is offline above to keep CI off OSM.
        if name != "City Drift" { view.startAnimation(); view.animateOneFrame(); view.stopAnimation() }
        print("Loaded \(name).saver and its configuration sheet")
    }
    print("Rendered all three savers, five aspect ratios, six map palettes and every cosmos view offline.")
} else {
    let delegate = PreviewDelegate(); app.delegate = delegate; app.run()
}
