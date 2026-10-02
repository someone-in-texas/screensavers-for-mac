import AppKit

/// Explicit panel presentation also works when hosted inside System Settings' sheet.
final class PickerColorWell: NSColorWell {
    override func mouseDown(with event: NSEvent) { showPanel() }
    override func accessibilityPerformPress() -> Bool { showPanel(); return true }
    private func showPanel() {
        activate(true)
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.makeKeyAndOrderFront(nil)
    }
}

final class ConfigurationController: NSWindowController {
    private let store: SettingsStore
    private let changed: (SaverSettings) -> Void
    private var controls: [String: NSControl] = [:]
    init(store: SettingsStore, changed: @escaping (SaverSettings) -> Void) {
        self.store = store; self.changed = changed
        super.init(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: store.kind == .worldClockRoom ? 400 : (store.kind == .dapple || store.kind == .flourish || store.kind == .lattice || store.kind == .strawberryFieldsForever || store.kind == .goodResearchTakesTime) ? 700 : store.kind == .voxelCosmos ? 650 : 610), styleMask: [.titled], backing: .buffered, defer: false))
        window?.title = store.kind.title
        window?.isReleasedWhenClosed = false
        build()
    }
    required init?(coder: NSCoder) { nil }
    func prepareForPresentation() {
        guard let window, !window.isVisible, window.sheetParent == nil else { return }
        build()
    }
    private func build() {
        guard let content = window?.contentView else { return }
        content.subviews.forEach { $0.removeFromSuperview() }; controls.removeAll()
        var y: CGFloat = content.bounds.height - 60
        let title = NSTextField(labelWithString: store.kind.title)
        title.font = .systemFont(ofSize: 21, weight: .semibold); title.frame = NSRect(x: 26, y: y, width: 390, height: 30)
        content.addSubview(title); y -= 45
        func row(_ label: String, _ key: String, _ control: NSControl) {
            let field = NSTextField(labelWithString: label); field.frame = NSRect(x: 28, y: y + 4, width: 150, height: 22)
            control.frame = NSRect(x: 190, y: y, width: 260, height: 28)
            control.setAccessibilityLabel(label)
            control.target = self; control.action = #selector(update)
            content.addSubview(field); content.addSubview(control); controls[key] = control; y -= 36
        }
        let s = store.value
        func slider(_ value: Double, _ min: Double, _ max: Double) -> NSSlider { NSSlider(value: value, minValue: min, maxValue: max, target: nil, action: nil) }
        func check(_ value: Bool) -> NSButton { let b = NSButton(checkboxWithTitle: "", target: nil, action: nil); b.state = value ? .on : .off; return b }
        if store.kind == .worldClockRoom {
            let floor = PickerColorWell(); floor.color = s.floor.color
            let face = PickerColorWell(); face.color = s.face.color
            row("Floor color", "floor", floor); row("Clock color", "face", face)
            row("Camera speed", "speed", slider(s.speed, 0, SaverSettings.maximumSpeed))
            row("Clock density", "density", slider(s.density, 0.7, 1.4))
            row("Smooth seconds", "smooth", check(s.smoothSeconds))
            row("City labels", "labels", check(s.labels))
        } else if store.kind == .voxelCosmos {
            func popup(_ titles: [String], _ index: Int) -> NSPopUpButton {
                let p = NSPopUpButton(); p.addItems(withTitles: titles); p.selectItem(at: index); return p
            }
            let v = s.cosmos
            row("View", "cosmosView", popup(CosmosView.allCases.map(\.title), CosmosView.allCases.firstIndex(of: v.view)!))
            row("Composition", "cosmosComposition", popup(CosmosComposition.allCases.map(\.title), CosmosComposition.allCases.firstIndex(of: v.composition)!))
            row("Camera angle", "cosmosAngle", popup(CosmosAngle.allCases.map(\.title), CosmosAngle.allCases.firstIndex(of: v.angle)!))
            row("Background", "cosmosBackground", popup(CosmosBackground.allCases.map(\.title), CosmosBackground.allCases.firstIndex(of: v.background)!))
            row("Seconds per view", "cosmosDuration", slider(v.secondsPerView, 15, 120))
            addValueLabel(key: "cosmosDuration", text: "\(Int(v.secondsPerView)) s", content: content)
            row("Motion speed", "cosmosSpeed", slider(v.speed, 0, 3))
            let pixels = NSSlider(value: v.pixelSize, minValue: 2, maxValue: 5, target: nil, action: nil)
            pixels.numberOfTickMarks = 4; pixels.allowsTickMarkValuesOnly = true
            row("Pixel size", "cosmosPixels", pixels)
            addValueLabel(key: "cosmosPixels", text: "\(Int(v.pixelSize))", content: content)
            row("Soft glow", "cosmosGlow", slider(v.glow, 0, 1))
            row("Star density", "cosmosStars", slider(v.starDensity, 0, 1))
            row("Orbit guides", "cosmosOrbits", check(v.orbits))
            row("Asteroids", "cosmosAsteroids", check(v.asteroids))
            row("Scene captions", "cosmosLabels", check(v.labels))
            let note = NSTextField(wrappingLabelWithString: "A miniature imagined cosmos. Distances and sizes are artistic. Entirely offline. Zero motion holds drift; timed view changes continue.")
            note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor
            note.frame = NSRect(x: 28, y: 61, width: 424, height: 38); content.addSubview(note)
        } else if store.kind == .strawberryFieldsForever {
            func popup(_ titles:[String],_ index:Int)->NSPopUpButton {let p=NSPopUpButton();p.addItems(withTitles:titles);p.selectItem(at:index);return p}
            let v=s.strawberry
            row("Lore density","strawberryLore",popup(StrawberryLore.allCases.map {$0.title},StrawberryLore.allCases.firstIndex(of:v.lore)!))
            row("Environment balance","strawberryBalance",popup(StrawberryBalance.allCases.map {$0.title},StrawberryBalance.allCases.firstIndex(of:v.balance)!))
            row("Camera speed","strawberryPace",popup(StrawberryPace.allCases.map {$0.rawValue.capitalized},StrawberryPace.allCases.firstIndex(of:v.pace)!))
            row("Hype weather","strawberryWeather",popup(StrawberryWeather.allCases.map {$0.rawValue.capitalized},StrawberryWeather.allCases.firstIndex(of:v.weather)!))
            row("Network visibility","strawberryNetwork",popup(StrawberryNetwork.allCases.map {$0.rawValue.capitalized},StrawberryNetwork.allCases.firstIndex(of:v.network)!))
            row("Palette","strawberryPalette",popup(StrawberryPalette.allCases.map {$0.title},StrawberryPalette.allCases.firstIndex(of:v.palette)!))
            row("Wind","strawberryWind",popup(StrawberryWind.allCases.map {$0.rawValue.capitalized},StrawberryWind.allCases.firstIndex(of:v.wind)!))
            row("Strawberry density","strawberryDensity",popup(StrawberryDensity.allCases.map {$0.title},StrawberryDensity.allCases.firstIndex(of:v.density)!))
            row("Text fragments","strawberryText",popup(StrawberryText.allCases.map {$0.rawValue.capitalized},StrawberryText.allCases.firstIndex(of:v.text)!))
            row("Scene seed","strawberrySeedBehavior",popup(ArtSeed.allCases.map {$0.title},ArtSeed.allCases.firstIndex(of:v.seedBehavior)!))
            row("Fixed seed","strawberrySeed",NSTextField(string:String(v.seed)))
            let note=NSTextField(wrappingLabelWithString:"An impossible field above a fictional laboratory. Pure Art hides explicit lore and staged Easter eggs. Offline; daily seeds use UTC.")
            note.font = .systemFont(ofSize:11);note.textColor = .secondaryLabelColor
            note.frame=NSRect(x:28,y:72,width:424,height:65);content.addSubview(note)
            updateAvailability(s)
        } else if store.kind == .goodResearchTakesTime {
            func popup(_ titles:[String],_ index:Int)->NSPopUpButton {let p=NSPopUpButton();p.addItems(withTitles:titles);p.selectItem(at:index);return p}
            let v=s.research
            row("Lore density","researchLore",popup(ResearchLore.allCases.map {$0.title},ResearchLore.allCases.firstIndex(of:v.lore)!))
            row("Camera speed","researchPace",popup(ResearchPace.allCases.map {$0.title},ResearchPace.allCases.firstIndex(of:v.pace)!))
            row("Environment","researchEnvironment",popup(ResearchEnvironment.allCases.map {$0.title},ResearchEnvironment.allCases.firstIndex(of:v.environment)!))
            row("Palette","researchPalette",popup(ResearchPalette.allCases.map {$0.title},ResearchPalette.allCases.firstIndex(of:v.palette)!))
            row("Research activity","researchActivity",popup(ResearchActivity.allCases.map {$0.rawValue.capitalized},ResearchActivity.allCases.firstIndex(of:v.activity)!))
            row("Maze presence","researchMazes",popup(ResearchMazePresence.allCases.map {$0.rawValue.capitalized},ResearchMazePresence.allCases.firstIndex(of:v.mazes)!))
            row("Text","researchText",popup(ResearchText.allCases.map {$0.rawValue.capitalized},ResearchText.allCases.firstIndex(of:v.text)!))
            row("Scene seed","researchSeedBehavior",popup(ArtSeed.allCases.map {$0.title},ArtSeed.allCases.firstIndex(of:v.seedBehavior)!))
            row("Fixed seed","researchSeed",NSTextField(string:String(v.seed)))
            let note=NSTextField(wrappingLabelWithString:"A fictional research cave, original mazes, and patient experiments. Pure Art removes explicit lore. Entirely offline; daily seeds use UTC.")
            note.font = .systemFont(ofSize:11);note.textColor = .secondaryLabelColor
            note.frame=NSRect(x:28,y:72,width:424,height:65);content.addSubview(note)
            updateAvailability(s)
        } else if store.kind == .flourish {
            func popup(_ titles:[String],_ index:Int)->NSPopUpButton {let p=NSPopUpButton();p.addItems(withTitles:titles);p.selectItem(at:index);return p}
            let v=s.flourish
            row("Palette","flourishPalette",popup(FlourishPalette.allCases.map {$0.title},FlourishPalette.allCases.firstIndex(of:v.palette)!))
            row("Growth style","flourishStyle",popup(FlourishStyle.allCases.map {$0.rawValue.capitalized},FlourishStyle.allCases.firstIndex(of:v.style)!))
            row("Background","flourishBackground",popup(FlourishBackground.allCases.map {$0.rawValue.capitalized},FlourishBackground.allCases.firstIndex(of:v.background)!))
            row("Line character","flourishLine",popup(FlourishLine.allCases.map {$0.title},FlourishLine.allCases.firstIndex(of:v.line)!))
            row("Scene seed","flourishSeedBehavior",popup(ArtSeed.allCases.map {$0.title},ArtSeed.allCases.firstIndex(of:v.seedBehavior)!))
            row("Fixed seed","flourishSeed",NSTextField(string:String(v.seed)))
            row("Growth speed","flourishSpeed",slider(v.speed,0.3,2))
            row("Density","flourishDensity",slider(v.density,0,1))
            row("Flowers","flourishFlowers",slider(v.flowers,0,1))
            row("Leaves","flourishLeaves",slider(v.leaves,0,1))
            row("Watercolor wash","flourishWash",check(v.wash))
            row("Gentle breeze","flourishBreeze",check(v.breeze))
            let note=NSTextField(wrappingLabelWithString:"A botanical drawing grows, rests, and gently gives way to a new composition. Daily seeds use UTC. Entirely offline.")
            note.font = .systemFont(ofSize:11);note.textColor = .secondaryLabelColor
            note.frame=NSRect(x:28,y:72,width:424,height:65);content.addSubview(note)
            updateAvailability(s)
        } else if store.kind == .lattice {
            func popup(_ titles:[String],_ index:Int)->NSPopUpButton {let p=NSPopUpButton();p.addItems(withTitles:titles);p.selectItem(at:index);return p}
            let v=s.lattice
            row("Simulation","latticeMode",popup(LatticeMode.allCases.map {$0.rawValue.capitalized},LatticeMode.allCases.firstIndex(of:v.mode)!))
            row("Palette","latticePalette",popup(LatticePalette.allCases.map {$0.title},LatticePalette.allCases.firstIndex(of:v.palette)!))
            row("Pixel size","latticePixels",popup(LatticePixel.allCases.map {$0.rawValue.capitalized},LatticePixel.allCases.firstIndex(of:v.pixels)!))
            row("Grid treatment","latticeGrid",popup(LatticeGrid.allCases.map {$0.title},LatticeGrid.allCases.firstIndex(of:v.grid)!))
            row("Scene seed","latticeSeedBehavior",popup(ArtSeed.allCases.map {$0.title},ArtSeed.allCases.firstIndex(of:v.seedBehavior)!))
            row("Fixed seed","latticeSeed",NSTextField(string:String(v.seed)))
            row("Activity","latticeActivity",slider(v.activity,0,1))
            row("Generations / sec","latticeSpeed",slider(v.speed,5,18))
            row("Glow","latticeGlow",slider(v.glow,0,1))
            row("Light persistence","latticePersistence",slider(v.persistence,0,1))
            row("Events","latticeEvents",slider(v.events,0,1))
            let note=NSTextField(wrappingLabelWithString:"A luminous cellular ecosystem. Local seeds keep it alive without full-grid resets. Daily seeds use UTC. Entirely offline.")
            note.font = .systemFont(ofSize:11);note.textColor = .secondaryLabelColor
            note.frame=NSRect(x:28,y:72,width:424,height:65);content.addSubview(note)
            updateAvailability(s)
        } else if store.kind == .dapple {
            func popup(_ titles: [String], _ index: Int) -> NSPopUpButton {
                let p = NSPopUpButton(); p.addItems(withTitles: titles); p.selectItem(at: index); return p
            }
            let v = s.dapple
            row("Palette", "dapplePalette", popup(DapplePalette.allCases.map { $0.title }, DapplePalette.allCases.firstIndex(of: v.palette)!))
            row("Material", "dappleMaterial", popup(DappleMaterial.allCases.map { $0.rawValue.capitalized }, DappleMaterial.allCases.firstIndex(of: v.material)!))
            row("Motion", "dappleMotion", popup(DappleMotion.allCases.map { $0.rawValue.capitalized }, DappleMotion.allCases.firstIndex(of: v.motion)!))
            row("Dot count", "dappleDensity", popup(DappleDensity.allCases.map { $0.rawValue.capitalized }, DappleDensity.allCases.firstIndex(of: v.density)!))
            row("Dot size", "dappleSize", popup(DappleSize.allCases.map { $0.rawValue.capitalized }, DappleSize.allCases.firstIndex(of: v.size)!))
            row("Scene seed", "dappleSeedBehavior", popup(DappleSeed.allCases.map { $0.title }, DappleSeed.allCases.firstIndex(of: v.seedBehavior)!))
            let seed = NSTextField(string: String(v.seed))
            row("Fixed seed", "dappleSeed", seed)
            row("Motion speed", "dappleSpeed", slider(v.speed, 0.35, 1.7))
            row("Surface texture", "dappleTexture", slider(v.texture, 0, 1))
            row("Soft shadows", "dappleShadows", check(v.shadows))
            row("Paper background", "dappleBackground", check(v.backgroundTexture))
            row("Occasional events", "dappleEvents", check(v.events))
            let note = NSTextField(wrappingLabelWithString: "Tactile circles, invisible hills, unhurried surprises. Daily scenes use the UTC date; a fixed seed repeats the same starting composition. Entirely offline.")
            note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor
            note.frame = NSRect(x: 28, y: 72, width: 424, height: 65); content.addSubview(note)
            updateAvailability(s)
        } else if store.kind == .paperSky {
            func popup(_ titles: [String], _ index: Int) -> NSPopUpButton {
                let p = NSPopUpButton(); p.addItems(withTitles: titles); p.selectItem(at: index); return p
            }
            let v = s.paperSky
            row("Viewpoint", "paperCamera", popup(PaperCamera.allCases.map(\.title), PaperCamera.allCases.firstIndex(of: v.camera)!))
            row("Sunset colors", "paperPalette", popup(PaperPalette.allCases.map(\.title), PaperPalette.allCases.firstIndex(of: v.palette)!))
            row("Seconds per view", "paperDuration", slider(v.secondsPerView, 20, 120))
            addValueLabel(key: "paperDuration", text: "\(Int(v.secondsPerView)) s", content: content)
            row("Flight speed", "paperSpeed", slider(v.speed, 0, 3))
            row("Cloud cover", "paperClouds", slider(v.clouds, 0, 1))
            row("Other airplanes", "paperCompanions", check(v.companions))
            row("Vapor trails", "paperTrails", check(v.trails))
            row("Striped sun", "paperSun", check(v.sun))
            row("Soft glow", "paperGlow", slider(v.glow, 0, 1))
            let note = NSTextField(wrappingLabelWithString: "An endless flight through procedurally shaped skies. A new sky on each launch, with gradual camera changes. Entirely offline. Zero speed holds flight and sunset colors; viewpoint changes continue.")
            note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor
            note.frame = NSRect(x: 28, y: 72, width: 424, height: 65); content.addSubview(note)
        } else {
            let style = NSPopUpButton(); style.addItems(withTitles: ["Vector map · Worldwide · Online", "Line map · 3 cities · Offline", "Traditional map · Worldwide"])
            style.selectItem(at: MapStyle.allCases.firstIndex(of: s.mapStyle)!)
            row("Map style", "mapStyle", style)
            let palette = NSPopUpButton(); palette.addItems(withTitles: MapPalette.allCases.map { $0.rawValue.capitalized })
            palette.selectItem(at: MapPalette.allCases.firstIndex(of: s.palette)!)
            row("Color scheme", "palette", palette)
            row("Movement speed", "speed", slider(s.speed, 0, SaverSettings.maximumSpeed))
            row("Street labels", "streetLabels", check(s.streetLabels))
            row("Water", "water", check(s.water))
            row("Parks", "parks", check(s.parks))
            row("Points of interest", "pointsOfInterest", check(s.pointsOfInterest))
            row("Effect intensity", "intensity", slider(s.intensity, 0, 1))
            row("Paper grain", "grain", check(s.grain))
            row("Soft vignette", "vignette", check(s.vignette))
            row("City label", "labels", check(s.labels))
            let note = NSTextField(wrappingLabelWithString: "Online vectors: worldwide. Offline vectors: Paris, Boston and Tokyo. Traditional maps have fixed labels and details.")
            note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor
            note.frame = NSRect(x: 28, y: 61, width: 424, height: 34); content.addSubview(note)
            updateAvailability(s)
        }
        let reset = NSButton(title: "Reset to Defaults", target: self, action: #selector(reset))
        reset.frame = NSRect(x: 24, y: 20, width: 160, height: 32); reset.bezelStyle = .rounded
        let done = NSButton(title: "Done", target: self, action: #selector(done))
        done.frame = NSRect(x: 360, y: 20, width: 90, height: 32); done.bezelStyle = .rounded; done.keyEquivalent = "\r"
        content.addSubview(reset); content.addSubview(done)
    }
    private func addValueLabel(key: String, text: String, content: NSView) {
        guard let control = controls[key] else { return }
        control.frame.size.width = 206
        let label = NSTextField(labelWithString: text); label.alignment = .right
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.frame = NSRect(x: 403, y: control.frame.minY + 4, width: 47, height: 22)
        content.addSubview(label); controls[key + "Value"] = label
    }
    @objc private func update() {
        var value = store.value
        if let c = controls["floor"] as? NSColorWell { value.floor = RGB(c.color) }
        if let c = controls["face"] as? NSColorWell { value.face = RGB(c.color) }
        if let c = controls["speed"] { value.speed = c.doubleValue }
        if let c = controls["density"] { value.density = c.doubleValue }
        if let c = controls["intensity"] { value.intensity = c.doubleValue }
        if let c = controls["smooth"] as? NSButton { value.smoothSeconds = c.state == .on }
        if let c = controls["labels"] as? NSButton { value.labels = c.state == .on }
        if let c = controls["grain"] as? NSButton { value.grain = c.state == .on }
        if let c = controls["vignette"] as? NSButton { value.vignette = c.state == .on }
        if let c = controls["mapStyle"] as? NSPopUpButton { value.mapStyle = MapStyle.allCases[c.indexOfSelectedItem] }
        if let c = controls["streetLabels"] as? NSButton { value.streetLabels = c.state == .on }
        if let c = controls["water"] as? NSButton { value.water = c.state == .on }
        if let c = controls["parks"] as? NSButton { value.parks = c.state == .on }
        if let c = controls["pointsOfInterest"] as? NSButton { value.pointsOfInterest = c.state == .on }
        if let c = controls["palette"] as? NSPopUpButton { value.palette = MapPalette.allCases[c.indexOfSelectedItem] }
        if let c = controls["cosmosComposition"] as? NSPopUpButton { value.cosmos.composition = CosmosComposition.allCases[c.indexOfSelectedItem] }
        if let c = controls["cosmosView"] as? NSPopUpButton { value.cosmos.view = CosmosView.allCases[c.indexOfSelectedItem] }
        if let c = controls["cosmosAngle"] as? NSPopUpButton { value.cosmos.angle = CosmosAngle.allCases[c.indexOfSelectedItem] }
        if let c = controls["cosmosBackground"] as? NSPopUpButton { value.cosmos.background = CosmosBackground.allCases[c.indexOfSelectedItem] }
        if let c = controls["cosmosDuration"] { value.cosmos.secondsPerView = c.doubleValue }
        if let c = controls["cosmosSpeed"] { value.cosmos.speed = c.doubleValue }
        if let c = controls["cosmosPixels"] { value.cosmos.pixelSize = c.doubleValue }
        if let c = controls["cosmosGlow"] { value.cosmos.glow = c.doubleValue }
        if let c = controls["cosmosStars"] { value.cosmos.starDensity = c.doubleValue }
        if let c = controls["cosmosOrbits"] as? NSButton { value.cosmos.orbits = c.state == .on }
        if let c = controls["cosmosAsteroids"] as? NSButton { value.cosmos.asteroids = c.state == .on }
        if let c = controls["cosmosLabels"] as? NSButton { value.cosmos.labels = c.state == .on }
        controls["cosmosDurationValue"]?.stringValue = "\(Int(value.cosmos.secondsPerView)) s"
        controls["cosmosPixelsValue"]?.stringValue = "\(Int(value.cosmos.pixelSize))"
        if let c = controls["paperCamera"] as? NSPopUpButton { value.paperSky.camera = PaperCamera.allCases[c.indexOfSelectedItem] }
        if let c = controls["paperPalette"] as? NSPopUpButton { value.paperSky.palette = PaperPalette.allCases[c.indexOfSelectedItem] }
        if let c = controls["paperDuration"] { value.paperSky.secondsPerView = c.doubleValue }
        if let c = controls["paperSpeed"] { value.paperSky.speed = c.doubleValue }
        if let c = controls["paperClouds"] { value.paperSky.clouds = c.doubleValue }
        if let c = controls["paperGlow"] { value.paperSky.glow = c.doubleValue }
        if let c = controls["paperCompanions"] as? NSButton { value.paperSky.companions = c.state == .on }
        if let c = controls["paperTrails"] as? NSButton { value.paperSky.trails = c.state == .on }
        if let c = controls["paperSun"] as? NSButton { value.paperSky.sun = c.state == .on }
        controls["paperDurationValue"]?.stringValue = "\(Int(value.paperSky.secondsPerView)) s"
        if let c = controls["dapplePalette"] as? NSPopUpButton { value.dapple.palette = DapplePalette.allCases[c.indexOfSelectedItem] }
        if let c = controls["dappleMaterial"] as? NSPopUpButton { value.dapple.material = DappleMaterial.allCases[c.indexOfSelectedItem] }
        if let c = controls["dappleMotion"] as? NSPopUpButton { value.dapple.motion = DappleMotion.allCases[c.indexOfSelectedItem] }
        if let c = controls["dappleDensity"] as? NSPopUpButton { value.dapple.density = DappleDensity.allCases[c.indexOfSelectedItem] }
        if let c = controls["dappleSize"] as? NSPopUpButton { value.dapple.size = DappleSize.allCases[c.indexOfSelectedItem] }
        if let c = controls["dappleSeedBehavior"] as? NSPopUpButton { value.dapple.seedBehavior = DappleSeed.allCases[c.indexOfSelectedItem] }
        if let c = controls["dappleSpeed"] { value.dapple.speed = c.doubleValue }
        if let c = controls["dappleTexture"] { value.dapple.texture = c.doubleValue }
        if let c = controls["dappleShadows"] as? NSButton { value.dapple.shadows = c.state == .on }
        if let c = controls["dappleBackground"] as? NSButton { value.dapple.backgroundTexture = c.state == .on }
        if let c = controls["dappleEvents"] as? NSButton { value.dapple.events = c.state == .on }
        if let c = controls["dappleSeed"] {
            if let seed = UInt64(c.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) { value.dapple.seed = seed }
            else { c.stringValue = String(value.dapple.seed) }
        }
        if let c=controls["strawberryLore"] as? NSPopUpButton {value.strawberry.lore=StrawberryLore.allCases[c.indexOfSelectedItem]}
        if let c=controls["strawberryBalance"] as? NSPopUpButton {value.strawberry.balance=StrawberryBalance.allCases[c.indexOfSelectedItem]}
        if let c=controls["strawberryPace"] as? NSPopUpButton {value.strawberry.pace=StrawberryPace.allCases[c.indexOfSelectedItem]}
        if let c=controls["strawberryWeather"] as? NSPopUpButton {value.strawberry.weather=StrawberryWeather.allCases[c.indexOfSelectedItem]}
        if let c=controls["strawberryNetwork"] as? NSPopUpButton {value.strawberry.network=StrawberryNetwork.allCases[c.indexOfSelectedItem]}
        if let c=controls["strawberryPalette"] as? NSPopUpButton {value.strawberry.palette=StrawberryPalette.allCases[c.indexOfSelectedItem]}
        if let c=controls["strawberryWind"] as? NSPopUpButton {value.strawberry.wind=StrawberryWind.allCases[c.indexOfSelectedItem]}
        if let c=controls["strawberryDensity"] as? NSPopUpButton {value.strawberry.density=StrawberryDensity.allCases[c.indexOfSelectedItem]}
        if let c=controls["strawberryText"] as? NSPopUpButton {value.strawberry.text=StrawberryText.allCases[c.indexOfSelectedItem]}
        if let c=controls["strawberrySeedBehavior"] as? NSPopUpButton {value.strawberry.seedBehavior=ArtSeed.allCases[c.indexOfSelectedItem]}
        if let c=controls["strawberrySeed"] {if let seed=UInt64(c.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)){value.strawberry.seed=seed}else{c.stringValue=String(value.strawberry.seed)}}
        if let c=controls["researchLore"] as? NSPopUpButton {value.research.lore=ResearchLore.allCases[c.indexOfSelectedItem]}
        if let c=controls["researchPace"] as? NSPopUpButton {value.research.pace=ResearchPace.allCases[c.indexOfSelectedItem]}
        if let c=controls["researchEnvironment"] as? NSPopUpButton {value.research.environment=ResearchEnvironment.allCases[c.indexOfSelectedItem]}
        if let c=controls["researchPalette"] as? NSPopUpButton {value.research.palette=ResearchPalette.allCases[c.indexOfSelectedItem]}
        if let c=controls["researchActivity"] as? NSPopUpButton {value.research.activity=ResearchActivity.allCases[c.indexOfSelectedItem]}
        if let c=controls["researchMazes"] as? NSPopUpButton {value.research.mazes=ResearchMazePresence.allCases[c.indexOfSelectedItem]}
        if let c=controls["researchText"] as? NSPopUpButton {value.research.text=ResearchText.allCases[c.indexOfSelectedItem]}
        if let c=controls["researchSeedBehavior"] as? NSPopUpButton {value.research.seedBehavior=ArtSeed.allCases[c.indexOfSelectedItem]}
        if let c=controls["researchSeed"] {if let seed=UInt64(c.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)){value.research.seed=seed}else{c.stringValue=String(value.research.seed)}}
        if let c=controls["flourishPalette"] as? NSPopUpButton {value.flourish.palette=FlourishPalette.allCases[c.indexOfSelectedItem]}
        if let c=controls["flourishStyle"] as? NSPopUpButton {value.flourish.style=FlourishStyle.allCases[c.indexOfSelectedItem]}
        if let c=controls["flourishBackground"] as? NSPopUpButton {value.flourish.background=FlourishBackground.allCases[c.indexOfSelectedItem]}
        if let c=controls["flourishLine"] as? NSPopUpButton {value.flourish.line=FlourishLine.allCases[c.indexOfSelectedItem]}
        if let c=controls["flourishSeedBehavior"] as? NSPopUpButton {value.flourish.seedBehavior=ArtSeed.allCases[c.indexOfSelectedItem]}
        if let c=controls["flourishSpeed"] {value.flourish.speed=c.doubleValue}
        if let c=controls["flourishDensity"] {value.flourish.density=c.doubleValue}
        if let c=controls["flourishFlowers"] {value.flourish.flowers=c.doubleValue}
        if let c=controls["flourishLeaves"] {value.flourish.leaves=c.doubleValue}
        if let c=controls["flourishWash"] as? NSButton {value.flourish.wash=c.state == .on}
        if let c=controls["flourishBreeze"] as? NSButton {value.flourish.breeze=c.state == .on}
        if let c=controls["flourishSeed"] {if let seed=UInt64(c.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)){value.flourish.seed=seed}else{c.stringValue=String(value.flourish.seed)}}
        if let c=controls["latticeMode"] as? NSPopUpButton {value.lattice.mode=LatticeMode.allCases[c.indexOfSelectedItem]}
        if let c=controls["latticePalette"] as? NSPopUpButton {value.lattice.palette=LatticePalette.allCases[c.indexOfSelectedItem]}
        if let c=controls["latticePixels"] as? NSPopUpButton {value.lattice.pixels=LatticePixel.allCases[c.indexOfSelectedItem]}
        if let c=controls["latticeGrid"] as? NSPopUpButton {value.lattice.grid=LatticeGrid.allCases[c.indexOfSelectedItem]}
        if let c=controls["latticeSeedBehavior"] as? NSPopUpButton {value.lattice.seedBehavior=ArtSeed.allCases[c.indexOfSelectedItem]}
        if let c=controls["latticeActivity"] {value.lattice.activity=c.doubleValue}
        if let c=controls["latticeSpeed"] {value.lattice.speed=c.doubleValue}
        if let c=controls["latticeGlow"] {value.lattice.glow=c.doubleValue}
        if let c=controls["latticePersistence"] {value.lattice.persistence=c.doubleValue}
        if let c=controls["latticeEvents"] {value.lattice.events=c.doubleValue}
        if let c=controls["latticeSeed"] {if let seed=UInt64(c.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)){value.lattice.seed=seed}else{c.stringValue=String(value.lattice.seed)}}
        store.value = value; changed(value); updateAvailability(value)
    }
    private func updateAvailability(_ value: SaverSettings) {
        controls["strawberrySeed"]?.isEnabled = value.strawberry.seedBehavior == .fixed
        controls["researchSeed"]?.isEnabled = value.research.seedBehavior == .fixed
        controls["strawberryText"]?.isEnabled = value.strawberry.lore != .pureArt
        controls["researchText"]?.isEnabled = value.research.lore != .pureArt
        controls["flourishSeed"]?.isEnabled = value.flourish.seedBehavior == .fixed
        controls["latticeSeed"]?.isEnabled = value.lattice.seedBehavior == .fixed
        controls["dappleSeed"]?.isEnabled = value.dapple.seedBehavior == .fixed
        for key in ["streetLabels", "water", "parks", "pointsOfInterest"] { controls[key]?.isEnabled = value.mapStyle != .traditional }
        for key in ["grain", "intensity"] { controls[key]?.isEnabled = value.mapStyle == .traditional }
    }
    @objc private func reset() { store.reset(); changed(store.value); build() }
    @objc func done() {
        for well in controls.values.compactMap({ $0 as? NSColorWell }) { well.deactivate() }
        NSColorPanel.shared.close()
        guard let window else { return }
        if let parent = window.sheetParent { parent.endSheet(window, returnCode: .OK) }
        if NSApp.modalWindow === window { NSApp.stopModal(withCode: .OK) }
        window.orderOut(nil)
    }
}
