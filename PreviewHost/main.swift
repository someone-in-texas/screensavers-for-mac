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
    private var previewTimer: Timer?
    private var lastNativeFrame: Double?
    private let forcePreviewTimer = CommandLine.arguments.contains("--force-preview-timer")
    override func startAnimation() {
        guard previewTimer == nil else { return }
        lastNativeFrame = nil
        super.startAnimation()
        // Some macOS releases only drive ScreenSaverView inside the real saver
        // host. Supply a standalone clock when native callbacks are absent.
        let timer = Timer(timeInterval: animationTimeInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let native = self.lastNativeFrame, ProcessInfo.processInfo.systemUptime - native < 0.25 { return }
            self.renderPreviewFrame()
        }
        previewTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    override func stopAnimation() {
        previewTimer?.invalidate(); previewTimer = nil
        super.stopAnimation()
    }
    override func animateOneFrame() {
        guard !forcePreviewTimer else { return }
        lastNativeFrame = ProcessInfo.processInfo.systemUptime
        renderPreviewFrame()
    }
    deinit { previewTimer?.invalidate() }
    private func renderPreviewFrame() {
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
        picker.frame = NSRect(x: 18, y: 752, width: 250, height: 28); picker.autoresizingMask = [.minYMargin]
        let configure = NSButton(title: "Configure…", target: self, action: #selector(configure))
        configure.bezelStyle = .rounded; configure.frame = NSRect(x: 280, y: 752, width: 120, height: 28); configure.autoresizingMask = [.minYMargin]
        let full = NSButton(title: "Full Screen", target: self, action: #selector(fullScreen))
        full.bezelStyle = .rounded; full.frame = NSRect(x: 408, y: 752, width: 120, height: 28); full.autoresizingMask = [.minYMargin]
        let save = NSButton(title: "Save Frame…", target: self, action: #selector(saveFrame))
        save.bezelStyle = .rounded; save.frame = NSRect(x: 536, y: 752, width: 130, height: 28); save.autoresizingMask = [.minYMargin]
        window.contentView?.addSubview(save)
        window.contentView?.addSubview(picker); window.contentView?.addSubview(configure); window.contentView?.addSubview(full)
        let menu = NSMenu(); let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit PreviewHost", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); appItem.submenu = appMenu
        NSApp.mainMenu = menu
        if CommandLine.arguments.contains("--map") { picker.selectItem(at: 1) }
        if CommandLine.arguments.contains("--cosmos") || CommandLine.arguments.contains("--cosmos-review") { picker.selectItem(at: 2) }
        if CommandLine.arguments.contains("--paper") || CommandLine.arguments.contains("--paper-review") { picker.selectItem(at: 3) }
        if CommandLine.arguments.contains("--dapple") || CommandLine.arguments.contains("--dapple-review") { picker.selectItem(at: 4) }
        if CommandLine.arguments.contains("--flourish") || CommandLine.arguments.contains("--flourish-review") { picker.selectItem(at: 5) }
        if CommandLine.arguments.contains("--lattice") || CommandLine.arguments.contains("--lattice-review") { picker.selectItem(at: 6) }
        if CommandLine.arguments.contains("--strawberry") || CommandLine.arguments.contains("--strawberry-review") {picker.selectItem(at:7)}
        if CommandLine.arguments.contains("--research") || CommandLine.arguments.contains("--research-review") {picker.selectItem(at:8)}
        switchScene(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if let i = CommandLine.arguments.firstIndex(of: "--capture-after"), i + 1 < CommandLine.arguments.count,
           let seconds = Double(CommandLine.arguments[i + 1]), seconds.isFinite {
            DispatchQueue.main.asyncAfter(deadline: .now() + min(600, max(1, seconds))) {
                self.saveFrame()
                if CommandLine.arguments.contains("--capture-and-quit") { self.view?.stopAnimation(); NSApp.terminate(nil) }
            }
        }
        if CommandLine.arguments.contains("--launch-smoke") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.checkConfigurationCycle(0) }
        }
    }
    private func checkConfigurationCycle(_ index: Int, attempt: Int = 0) {
        if (index == 0 || index % 6 == 5) && (view?.animationFrames ?? 0) <= 5 {
            precondition(attempt < 50, "Preview host must drive real animation frames for every saver")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.checkConfigurationCycle(index, attempt: attempt + 1) }
            return
        }
        if index == SaverKind.allCases.count * 6 { print("Passed \(index) configuration open/Done/reopen cycles across all savers."); view?.stopAnimation(); NSApp.terminate(nil); return }
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
        let review = CommandLine.arguments.contains("--online-vector") || CommandLine.arguments.contains("--cosmos-review") || CommandLine.arguments.contains("--paper-review") || CommandLine.arguments.contains("--dapple-review") || CommandLine.arguments.contains("--flourish-review") || CommandLine.arguments.contains("--lattice-review") || CommandLine.arguments.contains("--strawberry-review") || CommandLine.arguments.contains("--research-review")
        let store = SettingsStore(kind, defaults: (CommandLine.arguments.contains("--launch-smoke") || review) ? UserDefaults(suiteName: smokeSuite + kind.rawValue) : nil)
        if review {
            var settings = SaverSettings(); settings.cosmos.secondsPerView = 15; settings.paperSky.secondsPerView = 20; settings.mapStyle = .online; settings.palette = .blueprint
            if CommandLine.arguments.contains("--details") { settings.streetLabels = true; settings.water = true; settings.parks = true; settings.pointsOfInterest = true }
            if let i = CommandLine.arguments.firstIndex(of: "--map-palette"), i+1 < CommandLine.arguments.count, let palette = MapPalette(rawValue: CommandLine.arguments[i+1]) { settings.palette = palette }
            if CommandLine.arguments.contains("--dapple-review") { settings.dapple.seedBehavior = .fixed }
            if CommandLine.arguments.contains("--flourish-review") { settings.flourish.seedBehavior = .fixed }
            if CommandLine.arguments.contains("--lattice-review") { settings.lattice.seedBehavior = .fixed }
            if CommandLine.arguments.contains("--strawberry-review") {settings.strawberry.seedBehavior = .fixed}
            if CommandLine.arguments.contains("--research-review") {settings.research.seedBehavior = .fixed}
            if CommandLine.arguments.contains("--lore") {settings.research.loreMode=true;settings.strawberry.loreMode=true}
            if let i=CommandLine.arguments.firstIndex(of:"--seed"),i+1<CommandLine.arguments.count,let seed=UInt64(CommandLine.arguments[i+1]) {settings.research.seed=seed;settings.strawberry.seed=seed}
            if let i=CommandLine.arguments.firstIndex(of:"--composition"),i+1<CommandLine.arguments.count {
                settings.research.fineArt.composition=ResearchComposition(rawValue:CommandLine.arguments[i+1]) ?? settings.research.fineArt.composition
                settings.strawberry.fineArt.composition=StrawberryComposition(rawValue:CommandLine.arguments[i+1]) ?? settings.strawberry.fineArt.composition
            }
            store.value = settings
        }
        let noNetwork = CommandLine.arguments.contains("--offline") || CommandLine.arguments.contains("--launch-smoke")
        let fixed = CommandLine.arguments.firstIndex(of: "--city").flatMap { i in i + 1 < CommandLine.arguments.count ? CommandLine.arguments[i + 1] : nil }
        let scene: SaverScene = kind == .worldClockRoom ? WorldClockScene() : kind == .voxelCosmos ? VoxelCosmosScene() as SaverScene : kind == .paperSky ? PaperSkyScene() as SaverScene : kind == .dapple ? DappleScene() as SaverScene : kind == .flourish ? FlourishScene() as SaverScene : kind == .lattice ? LatticeScene() as SaverScene : kind == .strawberryFieldsForever ? StrawberryFieldsScene() as SaverScene : kind == .goodResearchTakesTime ? GoodResearchScene() as SaverScene : CityDriftScene(store: store, networkEnabled: !noNetwork, city: MapCity.all.first { $0.name == fixed }, visitCache: noNetwork && !CommandLine.arguments.contains("--launch-smoke") ? CityVisitCache() : nil)
        let frame = NSRect(x: 0, y: 0, width: window.contentView!.bounds.width, height: window.contentView!.bounds.height - 48)
        view = PreviewSaverView(frame: frame, isPreview: false, kind: kind, scene: scene, settingsStore: store)
        window.contentView?.addSubview(view!, positioned: .below, relativeTo: picker)
        view?.startAnimation()
        if review, (kind == .strawberryFieldsForever || kind == .goodResearchTakesTime),
           let i=CommandLine.arguments.firstIndex(of:"--review-age"),i+1<CommandLine.arguments.count,
           let age=Double(CommandLine.arguments[i+1]),age.isFinite,age>0,let root=view?.layer {
            for frame in 0...Int(min(7200,age)*4) {_ = scene.updateLayer(root,size:frameSize(),time:Double(frame)/4,date:Date())}
        }
    }
    private func frameSize()->CGSize {view?.bounds.size ?? .zero}
    @objc func configure() { if window.attachedSheet == nil, let sheet = view?.configureSheet { window.beginSheet(sheet) } }
    @objc func saveFrame() {
        guard let view, let layer = view.layer else { return }
        let size = Mercator.mapRenderSize(view.bounds.size, backingScale: window.backingScaleFactor)
        guard let c = bitmap(width: Int(size.width), height: Int(size.height)) else { return }
        c.scaleBy(x: size.width / view.bounds.width, y: size.height / view.bounds.height)
        layer.render(in: c)
        guard let image = c.makeImage() else { return }
        let filename = ["world-clock-room.png", "city-drift.png", "voxel-cosmos.png", "paper-sky.png", "dapple.png", "flourish.png", "lattice.png", "strawberry-fields-forever.png", "good-research-takes-time.png"][picker.indexOfSelectedItem]
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
        if CommandLine.arguments.contains("--launch-smoke") || CommandLine.arguments.contains("--online-vector") || CommandLine.arguments.contains("--cosmos-review") || CommandLine.arguments.contains("--paper-review") || CommandLine.arguments.contains("--dapple-review") || CommandLine.arguments.contains("--flourish-review") || CommandLine.arguments.contains("--lattice-review") || CommandLine.arguments.contains("--strawberry-review") || CommandLine.arguments.contains("--research-review") {
            for kind in SaverKind.allCases { UserDefaults.standard.removePersistentDomain(forName: smokeSuite + kind.rawValue) }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
if CommandLine.arguments.contains("--fine-gallery") {
    let args=CommandLine.arguments
    let out=args.firstIndex(of:"--output").flatMap { $0+1<args.count ? args[$0+1]:nil } ?? "build/fine-gallery"
    let seed=args.firstIndex(of:"--seed").flatMap { $0+1<args.count ? UInt64(args[$0+1]):nil } ?? 42
    try FileManager.default.createDirectory(atPath:out,withIntermediateDirectories:true)
    for research in [true,false] {
        for variant in 0..<(args.contains("--extended") ? 8:2) {
            var s=SaverSettings()
            if variant==1 {s.research.fineArt.palette = .charcoal;s.strawberry.fineArt.palette = .night}
            if variant==2 {s.research.fineArt.composition = .radial;s.strawberry.fineArt.composition = .asymmetric}
            if variant==3 {s.research.fineArt.palette = .blueprint;s.research.fineArt.drawing = .recursive;s.strawberry.fineArt.palette = .sage;s.strawberry.fineArt.blend = .synthetic}
            if variant==6 {s.research.fineArt.density = .dense;s.strawberry.fineArt.composition = .clustered}
            if variant==7 {s.research.fineArt.palette = .nocturne;s.strawberry.fineArt.palette = .charcoal}
            let scene=FineArtScene(research:research,seed:seed)
            let size=variant==4 ? CGSize(width:280,height:180):variant==5 ? CGSize(width:800,height:1400):variant==7 ? CGSize(width:3440,height:1440):CGSize(width:1600,height:1000)
            let root=CALayer();root.bounds=CGRect(origin:.zero,size:size);scene.apply(s);scene.start()
            var timings:[Double]=[]
            for frame in 0...3600 {
                let begin=ProcessInfo.processInfo.systemUptime
                _=scene.updateLayer(root,size:size,time:Double(frame)/4,date:Date(timeIntervalSince1970:0))
                if frame>0 {timings.append((ProcessInfo.processInfo.systemUptime-begin)*1000)}
                if [0,32,100,220,240,1200,3600].contains(frame) || (args.contains("--motion-samples") && variant==0 && (228...248).contains(frame)) {
                    let c=bitmap(width:Int(size.width),height:Int(size.height))!;root.render(in:c)
                    try savePNG(c.makeImage()!,"\(out)/\(research ? "research":"strawberry")-\(variant)-\(frame/4)\(args.contains("--motion-samples") && ![0,32,100,220,240,1200,3600].contains(frame) ? "-frame\(frame)":"").png")
                }
            }
            timings.sort();print("\(research ? "research":"strawberry") \(variant) seed \(scene.seed), strokes \(scene.segmentCount), angle \(scene.chairAngle): CPU update p50 \(timings[1800]) ms p95 \(timings[3420]) ms max \(timings.last!) ms")
            scene.stop()
        }
    }
} else
if CommandLine.arguments.contains("--lore-gallery") {
let out=CommandLine.arguments.firstIndex(of:"--output").flatMap {i in i+1<CommandLine.arguments.count ? CommandLine.arguments[i+1]:nil} ?? "build/lore-gallery"
try FileManager.default.createDirectory(atPath:out,withIntermediateDirectories:true)
for name in ["strawberry","research"] {
 for variant in 0..<9 {
  let seed:UInt64=variant==1 || variant==3 ? 91:variant==6 ? 807:42
  var settings=SaverSettings();settings.strawberry.loreMode=true;settings.research.loreMode=true
  if variant==1 {settings.strawberry.palette = .moonlit;settings.research.palette = .archive;settings.research.environment = .archive}
  if variant==2 {settings.strawberry.balance = .moreBasement;settings.strawberry.network = .visible;settings.research.palette = .deepResearch;settings.research.environment = .deepLab}
  if variant==3 {settings.strawberry.lore = .pureArt;settings.research.lore = .pureArt}
  if variant==6 {settings.strawberry.palette = .monochromeRed;settings.strawberry.density = .fieldsForever;settings.research.palette = .monochrome;settings.research.mazes = .frequent}
  if variant==7 {settings.strawberry.lore = .terminallyOnline;settings.strawberry.text = .normal;settings.strawberry.balance = .moreBasement;settings.research.lore = .deepLore;settings.research.text = .lore;settings.research.environment = .cave}
  let scene:SaverScene=name=="strawberry" ? StrawberryFieldsScene(seed:seed):GoodResearchScene(seed:seed)
  let size=variant==4 ? CGSize(width:280,height:180):variant==5 ? CGSize(width:800,height:1400):variant==8 ? CGSize(width:3440,height:1440):CGSize(width:1600,height:1000)
  let root=CALayer();root.bounds=CGRect(origin:.zero,size:size);scene.apply(settings);scene.start()
  var times:[Double]=[]
  for frame in 0...(variant==7 ? 10400:3600) {
   let t=Double(frame)/4,begin=ProcessInfo.processInfo.systemUptime
   _=scene.updateLayer(root,size:size,time:t,date:Date(timeIntervalSince1970:0));times.append((ProcessInfo.processInfo.systemUptime-begin)*1000)
   if [0,244,280,720,1244,1680,2400,2880,3360,3400,3600,8728,9224,10360].contains(frame) || ((variant==0 || variant==2) && frame%120==0 && (840...3360).contains(frame)) {
    let c=bitmap(width:Int(size.width),height:Int(size.height))!;root.render(in:c)
    let rep=NSBitmapImageRep(cgImage:c.makeImage()!);try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"\(out)/\(name)-\(variant)-\(Int(t)).png"))
   }
  }
  times.sort();print("\(name) \(variant): p50 \(times[1800]) p95 \(times[3420]) max \(times.last!)");scene.stop()
 }
}

} else if CommandLine.arguments.contains("--art-gallery") {
    let folder=CommandLine.arguments.firstIndex(of:"--output").flatMap {i in i+1<CommandLine.arguments.count ? CommandLine.arguments[i+1]:nil} ?? "build/art-gallery"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    let seed=CommandLine.arguments.firstIndex(of:"--seed").flatMap {i in i+1<CommandLine.arguments.count ? UInt64(CommandLine.arguments[i+1]):nil} ?? 42
    for kind in [SaverKind.flourish,.lattice] {
        let extended=CommandLine.arguments.contains("--art-extended")
        let variants=extended ? 8:4
        for variant in 0..<variants {
            let scene:SaverScene=kind == .flourish ? FlourishScene(seed:seed):LatticeScene(seed:seed)
            var s=SaverSettings()
            let v=variant<4 ? variant:0
            if kind == .flourish {
                s.flourish.palette=[.botanical,.midnight,.porcelain,.copperplate][v]
                s.flourish.style=[.natural,.spiral,.ornamental,.sparse][v]
                if variant==6 {s.flourish.style = .wild;s.flourish.palette = .autumn;s.flourish.density=1}
                if variant==7 {s.flourish.line = .brushPen;s.flourish.palette = .frost;s.flourish.breeze=true}
            } else {
                s.lattice.mode=[.reef,.bloom,.signal,.drift][v]
                s.lattice.palette=[.bioluminescent,.deepWell,.amber,.paper][v]
                if variant==6 {s.lattice.glow=0}
                if variant==7 {s.lattice.glow=1}
            }
            scene.apply(s);scene.start()
            let root=CALayer(),size=variant==4 ? CGSize(width:280,height:180):variant==5 ? CGSize(width:800,height:1400):CGSize(width:1600,height:1000)
            root.bounds=CGRect(origin:.zero,size:size)
            var timings:[Double]=[]
            for frame in 0...3400 {
                let begin=ProcessInfo.processInfo.systemUptime
                _ = scene.updateLayer(root,size:size,time:Double(frame)/10,date:Date(timeIntervalSince1970:0))
                timings.append((ProcessInfo.processInfo.systemUptime-begin)*1000)
                if [0,300,600,900,1200,1500,1800,2100,2600,2850,3000,3400].contains(frame) {
                    let c=bitmap(width:Int(size.width),height:Int(size.height))!;c.interpolationQuality = kind == .lattice ? .none:.high;root.render(in:c)
                    try savePNG(c.makeImage()!,"\(folder)/\(kind.rawValue)-\(variant)-\(frame).png")
                }
            }
            timings.sort();print("\(kind.rawValue) variant \(variant) CPU update p50 \(timings[1700]) ms p95 \(timings[3230]) ms max \(timings.last!) ms")
            scene.stop()
        }
    }
} else if CommandLine.arguments.contains("--dapple-gallery") {
    let folder = CommandLine.arguments.firstIndex(of: "--output").flatMap { i in i+1 < CommandLine.arguments.count ? CommandLine.arguments[i+1] : nil } ?? "build/dapple-gallery"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    let gallerySeed = CommandLine.arguments.firstIndex(of: "--seed").flatMap { i in i+1 < CommandLine.arguments.count ? UInt64(CommandLine.arguments[i+1]) : nil } ?? 42
    let looks: [(DapplePalette,DappleMaterial,DappleMotion)] = [(.meadow,.paper,.hills),(.dusk,.soft,.float),(.nightGarden,.ink,.zen),(.bauhaus,.paper,.playground),(.seaside,.ceramic,.hills),(.autumn,.paper,.hills)]
    for (palette,material,motion) in looks {
        let scene = DappleScene(seed:gallerySeed), root = CALayer(), size = CGSize(width:1600,height:1000)
        var s = SaverSettings(); s.dapple.palette=palette; s.dapple.material=material; s.dapple.motion=motion
        scene.apply(s); scene.start()
        for frame in 0...9000 {
            _ = scene.updateLayer(root,size:size,time:Double(frame)/30,date:Date(timeIntervalSince1970:0))
            if [0,300,900,1800,3600,5400,9000].contains(frame) {
                let c = bitmap(width:1600,height:1000)!
                root.render(in:c); try savePNG(c.makeImage()!, "\(folder)/\(palette.rawValue)-\(frame).png")
                if palette == .meadow && frame == 3600 {
                    for comparison in DappleMaterial.allCases {
                        var samePose = s; samePose.dapple.material = comparison; scene.apply(samePose)
                        _ = scene.updateLayer(root,size:size,time:Double(frame)/30,date:Date())
                        root.render(in:c); try savePNG(c.makeImage()!, "\(folder)/material-\(comparison.rawValue).png")
                    }
                    scene.apply(s)
                }
            }
        }
        scene.stop()
    }
    let stress: [(Int,Int,DappleDensity,UInt64)] = [(280,180,.balanced,42),(800,1200,.balanced,91),(1600,1000,.sparse,91),(1600,1000,.full,17),(1600,1000,.balanced,91),(1600,1000,.balanced,807)]
    for (width,height,density,seed) in stress {
        let scene = DappleScene(seed:seed), root = CALayer(), size = CGSize(width:width,height:height)
        var s = SaverSettings(); s.dapple.density=density
        scene.apply(s); scene.start()
        for frame in 0...9000 {
            _ = scene.updateLayer(root,size:size,time:Double(frame)/30,date:Date(timeIntervalSince1970:0))
            if [3600,9000].contains(frame) {
                let c = bitmap(width:width,height:height)!; root.render(in:c)
                try savePNG(c.makeImage()!, "\(folder)/stress-\(seed)-\(density.rawValue)-\(width)x\(height)-\(frame).png")
            }
        }
        scene.stop()
    }
    for size in [CGSize(width:1920,height:1080),CGSize(width:2560,height:1440),CGSize(width:5120,height:2880),CGSize(width:800,height:1200)] {
        let scenes = [DappleScene(seed:gallerySeed),DappleScene(seed:91)], roots = [CALayer(),CALayer()]
        var timings: [Double] = []
        for scene in scenes { scene.start() }
        for frame in 0..<900 {
            let t = ProcessInfo.processInfo.systemUptime
            for i in 0..<2 { _ = scenes[i].updateLayer(roots[i],size:size,time:Double(frame)/30,date:Date()) }
            if frame > 0 { timings.append((ProcessInfo.processInfo.systemUptime-t)*1000) }
        }
        timings.sort(); print("Dapple two displays \(Int(size.width))x\(Int(size.height)): CPU p50 \(timings[timings.count/2]) ms, p95 \(timings[Int(Double(timings.count)*0.95)]) ms")
        if size.width <= 2560 {
            let c = bitmap(width:Int(size.width),height:Int(size.height))!; roots[0].render(in:c)
            try savePNG(c.makeImage()!, "\(folder)/size-\(Int(size.width))x\(Int(size.height)).png")
        }
        for scene in scenes { scene.stop() }
    }
} else if CommandLine.arguments.contains("--smoke") {
    let folder = CommandLine.arguments.firstIndex(of: "--output").flatMap { i in i + 1 < CommandLine.arguments.count ? CommandLine.arguments[i + 1] : nil } ?? "build/smoke"
    try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
    let suiteName = "screensavers.smoke.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = SettingsStore(.cityDrift, defaults: defaults)
    let map = CityDriftScene(store: store, networkEnabled: false, city: MapCity.all[0]); map.useFixture(fixtureTile())
    let clock = WorldClockScene()
    let sizes = [CGSize(width: 1600, height: 1000), CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1080), CGSize(width: 280, height: 180), CGSize(width: 800, height: 1200)]
    for (name, scene) in [("world-clock-room", clock as SaverScene), ("city-drift-fixture", map as SaverScene), ("voxel-cosmos", VoxelCosmosScene() as SaverScene), ("paper-sky", PaperSkyScene(seed: 42) as SaverScene), ("dapple", DappleScene(seed: 42) as SaverScene), ("flourish", FlourishScene(seed: 42) as SaverScene), ("lattice", LatticeScene(seed: 42) as SaverScene), ("strawberry-fields-forever", StrawberryFieldsScene(seed:42) as SaverScene), ("good-research-takes-time", GoodResearchScene(seed:42) as SaverScene)] {
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
    // Real bundled cartography at the default detail level, never live tiles.
    for city in StarterMaps.bundled.catalog {
        let scene = CityDriftScene(store: store, networkEnabled: false, city: city)
        var settings = SaverSettings(); settings.mapStyle = .lines
        scene.apply(settings); scene.start()
        for size in [CGSize(width: 1600, height: 1000), CGSize(width: 280, height: 180), CGSize(width: 800, height: 1200)] {
            let c = bitmap(width: Int(size.width), height: Int(size.height))!
            scene.draw(in: c, size: size, time: 0, date: Date(timeIntervalSince1970: 1780315800))
            precondition(scene.isDisplayingBundledMap && scene.displayedCityLabel.hasSuffix("*"))
            try savePNG(c.makeImage()!, "\(folder)/city-drift-offline-\(city.name.lowercased())-\(Int(size.width))x\(Int(size.height)).png")
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
    for camera in PaperCamera.allCases {
        for palette in PaperPalette.allCases {
            let scene = PaperSkyScene(seed: 42); var settings = SaverSettings()
            settings.paperSky.camera = camera; settings.paperSky.palette = palette
            scene.apply(settings); scene.start()
            let size = CGSize(width: 1600, height: 1000), c = bitmap(width: 1600, height: 1000)!
            scene.draw(in: c, size: size, time: 0, date: Date())
            try savePNG(c.makeImage()!, "\(folder)/paper-\(camera.rawValue)-\(palette.rawValue).png")
            scene.stop()
        }
    }
    let paperTour = PaperSkyScene(seed: 42); var paperTourSettings = SaverSettings()
    paperTourSettings.paperSky.secondsPerView = 20
    paperTour.apply(paperTourSettings); paperTour.start()
    let paperRoot = CALayer(), paperSize = CGSize(width: 1200, height: 800)
    for frame in 0...470 {
        let time = Double(frame)/10
        _ = paperTour.updateLayer(paperRoot, size: paperSize, time: time, date: Date())
        if [190, 235, 270, 435, 470].contains(frame) {
            let c = bitmap(width: 1200, height: 800)!
            paperTour.draw(in: c, size: paperSize, time: time, date: Date())
            try savePNG(c.makeImage()!, "\(folder)/paper-transition-\(frame).png")
        }
    }
    paperTour.stop()
    for composition in CosmosComposition.allCases {
        let scene = VoxelCosmosScene(); var settings = SaverSettings()
        settings.cosmos.view = .saturn; settings.cosmos.composition = composition
        scene.apply(settings); scene.start()
        let size = CGSize(width: 1200, height: 800), c = bitmap(width: 1200, height: 800)!
        scene.draw(in: c, size: size, time: 0, date: Date())
        try savePNG(c.makeImage()!, "\(folder)/cosmos-composition-\(composition.rawValue).png")
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
    for name in SaverKind.allCases.map(\.title) {
        guard let bundle = Bundle(url: products.appendingPathComponent("\(name).saver")),
              let type = bundle.principalClass as? ScreenSaverView.Type,
              let view = type.init(frame: NSRect(x: 0, y: 0, width: 300, height: 200), isPreview: true),
              view.hasConfigureSheet, view.configureSheet != nil else { fatalError("Bundle load failed: \(name)") }
        // Start/stop the clock; map scene smoke is offline above to keep CI off OSM.
        if name != "City Drift" { view.startAnimation(); view.animateOneFrame(); view.stopAnimation() }
        if name == "Good Research Takes Time" || name == "Strawberry Fields Forever" {
            // Reproduce legacyScreenSaver's oversized Retina view, clipped by
            // its point-sized parent. Direct scene snapshots cannot catch this.
            let host=NSView(frame:NSRect(x:0,y:0,width:1710,height:1107))
            let hostWindow=NSWindow(contentRect:host.bounds,styleMask:.borderless,backing:.buffered,defer:false)
            hostWindow.contentView=host
            host.addSubview(view)
            for bounds in [NSRect(x:0,y:0,width:1710,height:1107),NSRect(x:80,y:40,width:800,height:1200)] {
                host.bounds=bounds
                view.frame=NSRect(x:0,y:0,width:3420,height:2214)
                view.layout();view.animateOneFrame()
                let visible=view.visibleRect.intersection(view.bounds)
                precondition(visible.width>0 && visible.width<view.bounds.width,"Host fixture must clip the oversized saver")
                guard let viewport=view.layer?.sublayers?.first(where:{$0.name=="scene-viewport"}) else {fatalError("Missing viewport layer")}
                let frame=viewport.frame
                precondition(abs(frame.minX-visible.minX)<0.001 && abs(frame.minY-visible.minY)<0.001 && abs(frame.width-visible.width)<0.001 && abs(frame.height-visible.height)<0.001 && viewport.bounds.origin == .zero,"Artwork must fit the visible host viewport: \(name)")
            }
            view.removeFromSuperview()
            hostWindow.contentView=nil
        }
        print("Loaded \(name).saver and its configuration sheet")
    }
    print("Rendered all nine savers, five aspect ratios, six map palettes and every cosmos view offline.")
} else {
    let delegate = PreviewDelegate(); app.delegate = delegate; app.run()
}
