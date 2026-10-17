import AppKit
final class BloomConfiguration: NotebookConfiguration {
    private weak var repeatControl: NSButton?
    private weak var seedField: NSTextField?
    private weak var seedFeedback: NSTextField?

    override func populate() {
        let s = store.value.bloom
        choice("Plant",value:s.plant,titles:BloomPlant.allCases.map(\.title)) { $0.bloom.plant = $1 }
        choice("Composition",value:s.layout) { $0.bloom.layout = $1 }
        choice("Palette",value:s.palette) { $0.bloom.palette = $1 }
        choice("Rendering",value:s.art.rendering,titles:BloomRendering.allCases.map(\.title)) { $0.bloom.art.rendering = $1 }
        choice("Pace",value:s.pace,titles:BloomPace.allCases.map { "\($0.rawValue.capitalized) (\(Int($0.secondsPerYear)) seconds/year)" }) { $0.bloom.pace = $1 }
        choice("Weather",value:s.weather) { $0.bloom.weather = $1 }
        choice("Paper texture",value:s.texture) { $0.bloom.texture = $1 }
        choice("Season emphasis",value:s.emphasis) { $0.bloom.emphasis = $1 }
        let repeatComposition = NSButton(checkboxWithTitle:"",target:nil,action:nil)
        repeatComposition.state = s.fixedSeedEnabled == true ? .on:.off
        repeatControl = repeatComposition
        row("Repeat composition",control:repeatComposition) { [weak self] control in
            guard let self, let button = control as? NSButton else { return }
            let enabled = button.state == .on
            self.window?.makeFirstResponder(nil)
            var value = self.store.value;value.bloom.fixedSeedEnabled = enabled
            self.store.value = value;self.changed(self.store.value)
            self.seedField?.isEnabled = enabled
            self.seedField?.stringValue = String(value.bloom.seed)
            self.showSeedFeedback(invalid:false)
        }
        let seed = NSTextField(string:String(s.seed))
        seedField = seed
        seed.isEnabled = s.fixedSeedEnabled == true
        row("Fixed seed",control:seed) { [weak self] control in
            guard let field = control as? NSTextField else { return }
            self?.applySeed(field)
        }
        let newComposition = NSButton(title:"New Composition",target:nil,action:nil)
        row("",control:newComposition) { [weak self] _ in
            guard let self else { return }
            self.window?.makeFirstResponder(nil)
            var value = self.store.value
            var seed = UInt64.random(in:0...UInt64.max)
            while seed == value.bloom.seed { seed = UInt64.random(in:0...UInt64.max) }
            value.bloom.seed = seed;value.bloom.fixedSeedEnabled = true
            self.store.value = value;self.changed(self.store.value)
            self.seedField?.isEnabled = true;self.repeatControl?.state = .on
            self.seedField?.stringValue = String(seed)
            self.showSeedFeedback(invalid:false)
        }
        newComposition.setAccessibilityLabel("New Composition")
        let feedback = NSTextField(wrappingLabelWithString:"")
        feedback.font = .systemFont(ofSize:12)
        feedback.frame = NSRect(x:26,y:cursor-32,width:468,height:32)
        window?.contentView?.addSubview(feedback);seedFeedback = feedback;cursor -= 40
        showSeedFeedback(invalid:false)
        note("Entirely offline. Season emphasis lengthens a season. Changes apply live. Revert Changes restores opening settings, even after Restore Defaults.",height:44)
    }

    func controlTextDidChange(_ notification:Notification) {
        guard let field = notification.object as? NSTextField, field === seedField else { return }
        showSeedFeedback(invalid:parsedSeed(field) == nil)
    }

    override func validateBeforeFinishing() -> Bool {
        guard let field = seedField, field.isEnabled else { return true }
        guard parsedSeed(field) != nil else {
            showSeedFeedback(invalid:true)
            window?.makeFirstResponder(field)
            return false
        }
        applySeed(field)
        return true
    }

    private func parsedSeed(_ field:NSTextField) -> UInt64? {
        let text = field.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
        return UInt64(text)
    }

    private func applySeed(_ field:NSTextField) {
        guard field.isEnabled else { return }
        guard let seed = parsedSeed(field) else {
            showSeedFeedback(invalid:true)
            return
        }
        field.stringValue = String(seed)
        showSeedFeedback(invalid:false)
        var value = store.value
        guard value.bloom.seed != seed || value.bloom.fixedSeedEnabled != true else { return }
        value.bloom.seed = seed;value.bloom.fixedSeedEnabled = true;store.value = value;changed(store.value)
    }

    private func showSeedFeedback(invalid:Bool) {
        seedFeedback?.textColor = invalid ? .systemRed:.secondaryLabelColor
        seedFeedback?.stringValue = invalid
            ? "Invalid seed. Enter a whole number from 0 to 18446744073709551615. The last valid seed is still applied."
            : "Repeat uses the same starting composition; off varies each launch. New Composition picks a seed."
        seedField?.setAccessibilityHelp(seedFeedback?.stringValue)
        seedField?.textColor = invalid ? .systemRed:.labelColor
    }
}
