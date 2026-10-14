import AppKit

/// Small native sheets used by the new savers; scene-specific actions stay in
/// their own subclasses, outside the host's lifecycle.
class NotebookConfiguration: NSWindowController, SaverConfiguration, NSTextFieldDelegate {
    let store: SettingsStore
    let changed: (SaverSettings) -> Void
    var cursor: CGFloat = 0
    private var actions: [ObjectIdentifier: (NSControl) -> Void] = [:]
    init(store: SettingsStore, changed: @escaping (SaverSettings) -> Void) {
        self.store = store; self.changed = changed
        super.init(window: NSWindow(contentRect: NSRect(x:0,y:0,width:520,height:650), styleMask:[.titled], backing:.buffered,defer:false))
        window?.title = store.kind.title; window?.isReleasedWhenClosed = false
    }
    required init?(coder: NSCoder) { nil }
    func prepareForPresentation() {
        guard let window, !window.isVisible, window.sheetParent == nil else { return }
        rebuildContents()
    }
    private func rebuildContents() {
        guard let window else { return }
        window.contentView?.subviews.forEach { $0.removeFromSuperview() }; actions.removeAll(); cursor = 594
        note(store.kind.title, height:38, size:23)
        populate()
        let done = NSButton(title:"Done",target:self,action:#selector(finish));done.frame = NSRect(x:404,y:20,width:88,height:30);done.keyEquivalent = "\r";window.contentView?.addSubview(done)
        let reset = NSButton(title:"Restore Defaults",target:self,action:#selector(resetSettings));reset.frame = NSRect(x:24,y:20,width:150,height:30);window.contentView?.addSubview(reset)
    }
    func populate() {}
    func note(_ text: String, height: CGFloat = 44, size: CGFloat = 12) {
        let label = NSTextField(wrappingLabelWithString:text);label.font = .systemFont(ofSize:size);label.textColor = size > 20 ? .labelColor:.secondaryLabelColor
        label.frame = NSRect(x:26,y:cursor-height+12,width:468,height:height);window?.contentView?.addSubview(label);cursor -= height
    }
    func row(_ title: String, control: NSControl, action: @escaping (NSControl) -> Void) {
        let label = NSTextField(labelWithString:title);label.frame = NSRect(x:26,y:cursor-24,width:170,height:24)
        control.frame = NSRect(x:206,y:cursor-26,width:286,height:28);control.setAccessibilityLabel(title);control.target = self;control.action = #selector(update(_:))
        if let field = control as? NSTextField { field.delegate = self }
        window?.contentView?.addSubview(label);window?.contentView?.addSubview(control);actions[ObjectIdentifier(control)] = action;cursor -= 36
    }
    func choice<T:RawRepresentable & CaseIterable & Equatable>(_ title:String, value:T, titles:[String]? = nil, set:@escaping (inout SaverSettings,T)->Void) where T.RawValue == String {
        let values = Array(T.allCases), popup = NSPopUpButton()
        popup.addItems(withTitles:titles ?? values.map { $0.rawValue.capitalized });popup.selectItem(at:values.firstIndex(of:value) ?? 0)
        row(title,control:popup) { [weak self] c in guard let self, let p = c as? NSPopUpButton, values.indices.contains(p.indexOfSelectedItem) else { return };var s = self.store.value;set(&s,values[p.indexOfSelectedItem]);self.store.value = s;self.changed(s) }
    }
    func toggle(_ title:String, value:Bool, set:@escaping (inout SaverSettings,Bool)->Void) {
        let control = NSButton(checkboxWithTitle:"",target:nil,action:nil);control.state = value ? .on:.off
        row(title,control:control) { [weak self] c in guard let self, let b = c as? NSButton else { return };var s = self.store.value;set(&s,b.state == .on);self.store.value = s;self.changed(s) }
    }
    func settingsDidChange() {}
    func controlTextDidEndEditing(_ notification:Notification) { if let field = notification.object as? NSTextField { update(field) } }
    @objc private func update(_ sender:NSControl) { actions[ObjectIdentifier(sender)]?(sender);settingsDidChange() }
    @objc private func finish() { dismiss(returnCode:.OK) }
    @objc private func resetSettings() { store.reset();changed(store.value);settingsDidChange();rebuildContents() }
    func dismiss(returnCode: NSApplication.ModalResponse) {
        guard let window else { return }
        if let parent = window.sheetParent { parent.endSheet(window,returnCode:returnCode) }
        if NSApp.modalWindow === window { NSApp.stopModal(withCode:returnCode) }
        window.orderOut(nil)
    }
}
