import AppKit

// Exercise real target/action and field-editor paths. Every store and archive is disposable.
private func configurationViews(_ view: NSView) -> [NSView] {
    [view] + view.subviews.flatMap(configurationViews)
}
private func configurationControl<T: NSControl>(_ controller: NSWindowController, _ label: String, as type: T.Type = T.self) -> T? {
    let matches = controller.window?.contentView.map(configurationViews)?.compactMap { $0 as? T }.filter {
        $0.accessibilityLabel() == label || ($0 as? NSButton)?.title == label
    } ?? []
    expect(matches.count == 1, "\(controller.window?.title ?? "Options"): unique \(label) control")
    return matches.first
}
private func configurationClick(_ controller: NSWindowController, _ title: String) {
    configurationControl(controller, title, as: NSButton.self)?.performClick(nil)
}
private func configurationSend(_ control: NSControl) {
    expect(control.sendAction(control.action, to: control.target), "Options control action is connected")
}
private func configurationEdit(_ controller: NSWindowController, _ field: NSTextField, _ text: String) {
    expect(controller.window?.makeFirstResponder(field) == true, "seed accepts keyboard focus")
    guard let editor = field.currentEditor() else { expect(false, "native field editor exists"); return }
    editor.string = text
    // The native editor owns the draft until editing ends; notify just as typing does.
    NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: field)
}
private func configurationFixture(_ kind: SaverKind, _ body: (SettingsStore) -> Void) {
    let suite = "screensavers.configuration.tests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else { expect(false, "isolated defaults available"); return }
    defer { defaults.removePersistentDomain(forName: suite) }
    body(SettingsStore(kind, defaults: defaults))
}

func runConfigurationTests() {
    _ = NSApplication.shared
    let start = checks
    configurationSharedTests()
    configurationSeedTests()
    configurationBloomTests()
    configurationCommonplaceTests()
    configurationLayoutTests()
    // Exact allowed output catches accidental additions of settings, paths or account data.
    for kind in SaverKind.allCases {
        let base = "Screensavers for Mac\nSaver: \(kind.title)\nVersion: test-version\nmacOS: test-os"
        expect(ConfigurationSupport.report(kind: kind, version: "test-version", os: "test-os", displaySize: nil, scale: nil) == base, "support report whitelist without display")
        expect(ConfigurationSupport.report(kind: kind, version: "test-version", os: "test-os", displaySize: CGSize(width: 1440, height: 900), scale: 2) == base + "\nOptions display: 1440 × 900 points, 2.0× scale", "support report whitelist with display")
        expect(ConfigurationSupport.report(kind: kind, version: "test-version", os: "test-os", displaySize: CGSize(width: 1440, height: 900), scale: nil) == base, "support report omits incomplete display")
    }
    print("Options UI: \(checks - start) behavioral checks")
}

private func configurationSharedTests() {
    // Explicit coverage inventory prevents a removed slider from silently reducing coverage.
    typealias SliderCase = (String, WritableKeyPath<SaverSettings, Double>, Double, String)
    let cases: [(SaverKind, [SliderCase])] = [
        (.worldClockRoom, [("Camera speed", \.speed, 8, "8.00×"), ("Clock density", \.density, 1.2, "1.20×")]),
        (.cityDrift, [("Movement speed", \.speed, 8, "8.00×"), ("Effect intensity", \.intensity, 0.75, "75%")]),
        (.voxelCosmos, [("Seconds per view", \.cosmos.secondsPerView, 90, "90 s"), ("Motion speed", \.cosmos.speed, 2, "2.00×"), ("Pixel size", \.cosmos.pixelSize, 4, "4 px"), ("Soft glow", \.cosmos.glow, 0.75, "75%"), ("Star density", \.cosmos.starDensity, 0.75, "75%")]),
        (.paperSky, [("Seconds per view", \.paperSky.secondsPerView, 90, "90 s"), ("Flight speed", \.paperSky.speed, 2, "2.00×"), ("Cloud cover", \.paperSky.clouds, 0.75, "75%"), ("Soft glow", \.paperSky.glow, 0.75, "75%")]),
        (.dapple, [("Motion speed", \.dapple.speed, 1.5, "1.50×"), ("Surface texture", \.dapple.texture, 0.75, "75%")]),
        (.flourish, [("Growth speed", \.flourish.speed, 1.5, "1.50×"), ("Density", \.flourish.density, 0.75, "75%"), ("Flowers", \.flourish.flowers, 0.75, "75%"), ("Leaves", \.flourish.leaves, 0.75, "75%")]),
        (.lattice, [("Activity", \.lattice.activity, 0.75, "75%"), ("Generations / sec", \.lattice.speed, 12, "12.0 /s"), ("Glow", \.lattice.glow, 0.75, "75%"), ("Light persistence", \.lattice.persistence, 0.75, "75%"), ("Events", \.lattice.events, 0.75, "75%")])
    ]
    for (kind, sliders) in cases {
        configurationFixture(kind) { store in
            var initial = store.value; initial.speed = 7; initial.mapStyle = .traditional; store.value = initial
            var delivered: [SaverSettings] = []
            let controller = ConfigurationController(store: store) { delivered.append($0) }
            defer { controller.dismiss(returnCode: .cancel) }
            controller.prepareForPresentation(); controller.window?.orderFront(nil)
            expect(controller.window?.isVisible == true, "Options is visible for presentation baseline test")
            for (label, key, value, readout) in sliders {
                guard let slider = configurationControl(controller, label, as: NSSlider.self) else { continue }
                slider.doubleValue = value; configurationSend(slider)
                near(store.value[keyPath: key], value, "\(kind): \(label) persisted")
                expect(delivered.last == store.value, "\(kind): \(label) live callback")
                expect(configurationControl(controller, label + " value", as: NSTextField.self)?.stringValue == readout, "\(kind): \(label) readout updates")
            }
            let committed = store.value
            expect(committed != initial, "slider fixture changes settings")
            controller.prepareForPresentation() // visible reads must not replace the baseline
            configurationClick(controller, "Restore Defaults")
            expect(store.value == SaverSettings(), "shared Restore Defaults applies defaults")
            configurationClick(controller, "Revert Changes")
            expect(store.value == initial && delivered.last == initial, "shared Revert restores opening even after reset and visible prepare")
            configurationClick(controller, "Done")
            store.value = committed // next opening observes an externally changed persisted value
            controller.prepareForPresentation(); controller.window?.orderFront(nil)
            configurationClick(controller, "Restore Defaults"); configurationClick(controller, "Revert Changes")
            expect(store.value == committed && delivered.last == committed, "shared reopen captures new baseline")
            for (label, key, _, _) in sliders {
                expect(configurationControl(controller, label, as: NSSlider.self)?.doubleValue == committed[keyPath: key], "Revert rebuilds slider \(label)")
            }
        }
    }
}

private func configurationSeedTests() {
    let seeds: [(SaverKind, WritableKeyPath<SaverSettings, UInt64>)] = [
        (.dapple, \.dapple.seed), (.flourish, \.flourish.seed), (.lattice, \.lattice.seed),
        (.strawberryFieldsForever, \.strawberry.seed), (.goodResearchTakesTime, \.research.seed)
    ]
    for (kind, key) in seeds {
        configurationFixture(kind) { store in
            var delivered: SaverSettings?
            let controller = ConfigurationController(store: store) { delivered = $0 }
            defer { controller.dismiss(returnCode: .cancel) }
            controller.prepareForPresentation(); controller.window?.orderFront(nil)
            configurationClick(controller, "New Seed")
            guard let field = configurationControl(controller, "Fixed seed", as: NSTextField.self) else { return }
            expect(field.isEnabled && UInt64(field.stringValue) == store.value[keyPath: key], "\(kind): New Seed selects fixed mode and persists displayed seed")
            let baseline = store.value[keyPath: key]
            for invalid in ["", "-1", "+1", "1.5", "18446744073709551616", "１２", "abc"] {
                configurationEdit(controller, field, invalid)
                configurationClick(controller, "Done")
                expect(store.value[keyPath: key] == baseline, "\(kind): invalid seed preserves last valid value")
                expect(controller.window?.isVisible == true && field.currentEditor() != nil, "\(kind): invalid Done keeps Options open and seed focused")
                expect(field.textColor == .systemRed, "\(kind): invalid seed has visible feedback")
            }
            configurationEdit(controller, field, "18446744073709551615")
            controller.window?.makeFirstResponder(nil)
            expect(store.value[keyPath: key] == UInt64.max, "\(kind): ending editing commits full UInt64 range")
            configurationEdit(controller, field, " 42 ")
            configurationClick(controller, "Done")
            expect(store.value[keyPath: key] == 42 && delivered == store.value, "\(kind): Done commits active editor")
            expect(controller.window?.isVisible == false, "\(kind): valid Done dismisses")
            controller.prepareForPresentation(); controller.window?.orderFront(nil)
            configurationClick(controller, "New Seed")
            configurationClick(controller, "Restore Defaults"); configurationClick(controller, "Revert Changes")
            expect(store.value[keyPath: key] == 42, "\(kind): seed reverts to reopened baseline after reset")
        }
    }
}

private func configurationBloomTests() {
    configurationFixture(.yearsInBloom) { store in
        var initial = store.value; initial.bloom.seed = 731; store.value = initial
        var delivered: SaverSettings?
        let controller = BloomConfiguration(store: store) { delivered = $0 }
        defer { controller.dismiss(returnCode: .cancel) }
        controller.prepareForPresentation(); controller.window?.orderFront(nil)
        configurationClick(controller, "New Composition")
        guard let field = configurationControl(controller, "Fixed seed", as: NSTextField.self) else { return }
        expect(store.value.bloom.seed != 731 && UInt64(field.stringValue) == store.value.bloom.seed, "Bloom New Composition changes and displays seed")
        expect(configurationControl(controller, "Repeat composition", as: NSButton.self)?.state == .on, "Bloom New Composition enables repetition")
        let lastValid = store.value.bloom.seed
        for invalid in ["", "-1", "+1", "1.5", "18446744073709551616", "１２", "abc"] {
            configurationEdit(controller, field, invalid); configurationClick(controller, "Done")
            expect(store.value.bloom.seed == lastValid, "Bloom invalid seed preserves applied composition")
            expect(controller.window?.isVisible == true && field.currentEditor() != nil, "Bloom invalid Done stays open and focuses seed")
            expect(field.textColor == .systemRed, "Bloom invalid seed feedback")
        }
        configurationEdit(controller, field, "18446744073709551615"); controller.window?.makeFirstResponder(nil)
        expect(store.value.bloom.seed == UInt64.max, "Bloom editing-end commits valid seed")
        configurationEdit(controller, field, "42"); configurationClick(controller, "Done")
        expect(store.value.bloom.seed == 42 && delivered == store.value, "Bloom Done commits editor")
        expect(controller.window?.isVisible == false, "Bloom valid Done dismisses")
        controller.prepareForPresentation(); controller.window?.orderFront(nil)
        let reopened = store.value
        configurationClick(controller, "New Composition"); controller.prepareForPresentation()
        configurationClick(controller, "Restore Defaults")
        expect(store.value == SaverSettings(), "Bloom reset applies defaults")
        configurationClick(controller, "Revert Changes")
        expect(store.value == reopened && delivered == reopened, "Bloom Revert keeps reopened baseline through reset")
        expect(configurationControl(controller, "Fixed seed", as: NSTextField.self)?.stringValue == "42", "Bloom Revert rebuilds seed field")
        configurationClick(controller, "Repeat composition")
        expect(store.value.bloom.fixedSeedEnabled == false, "Bloom explicitly disables repetition")
        configurationClick(controller, "Done")
        controller.prepareForPresentation(); controller.window?.orderFront(nil)
        expect(configurationControl(controller, "Fixed seed", as: NSTextField.self)?.isEnabled == false, "Bloom disabled repetition persists across reopen")
        configurationClick(controller, "New Composition"); configurationClick(controller, "Revert Changes")
        expect(store.value.bloom.fixedSeedEnabled == false && store.value.bloom.seed == 42, "Bloom Revert restores explicit fresh-launch choice")
        if let window = controller.window {
            ConfigurationPanelLayout.apply(to: window, preferredHeight: 650, visibleFrame: NSRect(x:0,y:0,width:1024,height:600))
            let scrolls = window.contentView.map(configurationViews)?.compactMap { $0 as? NSScrollView } ?? []
            expect(scrolls.count == 1 && window.frame.height <= 600, "Bloom Options adapts to a compact display")
            if let document = scrolls.first?.documentView, let done = configurationControl(controller, "Done", as: NSButton.self) {
                expect(!done.isDescendant(of: document), "Bloom Done remains outside scrolling settings")
            }
        }
    }
}

private func configurationCommonplaceTests() {
    configurationFixture(.commonplace) { store in
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("configuration-archive-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let bridge = root.appendingPathComponent("preferences.json")
            var initial = store.value; initial.commonplace.interests = ["botany"]; store.value = initial
            var delivered: SaverSettings?
            let controller = CommonplaceConfiguration(store: store) { delivered = $0 }
            controller.archive = CommonplaceArchive(root: root)
            defer { controller.dismiss(returnCode: .cancel) }
            controller.prepareForPresentation(); controller.window?.orderFront(nil)
            configurationClick(controller, "Original writing")
            expect(!FileManager.default.fileExists(atPath: bridge.path), "Commonplace does not create helper bridge without setup")
            try JSONEncoder().encode(initial.commonplace).write(to: bridge)
            configurationClick(controller, "Revert Changes")
            func bridged() -> CommonplaceSettings? { guard let data = try? Data(contentsOf: bridge) else { return nil }; return try? JSONDecoder().decode(CommonplaceSettings.self, from: data) }
            expect(bridged() == initial.commonplace, "Commonplace Revert bridges opening settings")
            guard let field = configurationControl(controller, "Interests", as: NSTextField.self) else { return }
            configurationEdit(controller, field, "astronomy, architecture"); configurationClick(controller, "Done")
            expect(store.value.commonplace.interests == ["astronomy", "architecture"], "Commonplace Done commits active interests editor")
            expect(bridged() == store.value.commonplace, "Commonplace editor commit reaches bridge")
            controller.prepareForPresentation(); controller.window?.orderFront(nil)
            let reopened = store.value
            configurationClick(controller, "Original writing"); controller.prepareForPresentation()
            configurationClick(controller, "Restore Defaults")
            expect(store.value == SaverSettings(), "Commonplace reset persists defaults")
            expect(bridged() == store.value.commonplace, "Commonplace reset bridges defaults")
            configurationClick(controller, "Revert Changes")
            expect(store.value == reopened && delivered == reopened, "Commonplace reopened baseline and callback survive reset")
            expect(bridged() == reopened.commonplace, "Commonplace Revert restores helper preferences")
        } catch { expect(false, "temporary Commonplace bridge: \(error)") }
    }
}

private func configurationLayoutTests() {
    configurationFixture(.lattice) { store in
        let controller = ConfigurationController(store: store) { _ in }
        defer { controller.dismiss(returnCode: .cancel) }
        let compactScreen = NSRect(x: 0, y: 0, width: 1024, height: 600)
        for _ in 0..<2 {
            // Rebuild after a close, then adapt using a deterministic small display.
            controller.prepareForPresentation()
            guard let window = controller.window, let content = window.contentView else { return }
            ConfigurationPanelLayout.apply(to: window, preferredHeight: 745, visibleFrame: compactScreen)
            let scrolls = configurationViews(content).compactMap { $0 as? NSScrollView }
            expect(scrolls.count == 1, "compact Options has one body scroll after rebuild")
            guard let scroll = scrolls.first, let document = scroll.documentView else { return }
            expect(window.frame.height <= compactScreen.height, "compact Options fits available display")
            expect(scroll.hasVerticalScroller && document.bounds.height > scroll.contentView.bounds.height, "compact Options body is scrollable")
            for title in ["Done", "Restore Defaults", "Revert Changes", "Copy Support Info"] {
                guard let button = configurationControl(controller, title, as: NSButton.self) else { continue }
                expect(!button.isDescendant(of: document), "\(title) stays outside scrolling body")
                let rect = button.convert(button.bounds, to: content)
                expect(rect.minY >= 0 && rect.maxY <= scroll.frame.minY, "\(title) footer is visible and does not overlap body")
            }
            guard let activity = configurationControl(controller, "Activity", as: NSSlider.self) else { return }
            expect(activity.isDescendant(of: document), "settings control lives in scrolling body")
            scroll.contentView.scroll(to: .zero)
            let offset = ConfigurationPanelLayout.distanceFromTop(in: window)
            expect(offset > 0, "body can scroll away from top")
            ConfigurationPanelLayout.apply(to: window, preferredHeight: 745, distanceFromTop: offset, visibleFrame: compactScreen)
            near(Double(ConfigurationPanelLayout.distanceFromTop(in: window)), Double(offset), "layout reapplication preserves scroll offset")
            expect(configurationViews(content).compactMap { $0 as? NSScrollView }.count == 1, "layout reapplication does not nest scroll views")
            configurationClick(controller, "Done")
        }
    }
}
