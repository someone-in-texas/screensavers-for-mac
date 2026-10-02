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
        super.init(window: NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: store.kind == .cityDrift ? 590 : 400), styleMask: [.titled], backing: .buffered, defer: false))
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
        store.value = value; changed(value); updateAvailability(value)
    }
    private func updateAvailability(_ value: SaverSettings) {
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
