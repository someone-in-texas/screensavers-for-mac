import AppKit
final class CommonplaceConfiguration: NotebookConfiguration {
    private var sourcesWindow: NSWindow?
    var archive: CommonplaceArchive?
    override func populate() {
        let s = store.value.commonplace
        choice("Theme",value:s.theme,titles:CommonplaceTheme.allCases.map(\.title)) { $0.commonplace.theme = $1 }
        choice("Pace",value:s.pace) { $0.commonplace.pace = $1 }
        choice("Page density",value:s.density) { $0.commonplace.density = $1 }
        toggle("Original writing",value:s.originalWriting) { $0.commonplace.originalWriting = $1 }
        toggle("Historical images",value:s.historicalImages) { $0.commonplace.historicalImages = $1 }
        toggle("Sketches & diagrams",value:s.diagrams) { $0.commonplace.diagrams = $1 }
        toggle("Verified quotations",value:s.quotations) { $0.commonplace.quotations = $1 }
        let interests = NSTextField(string:s.interests.joined(separator:", "))
        row("Interests",control:interests) { [weak self] c in
            guard let self,let field = c as? NSTextField else { return };var value = self.store.value
            value.commonplace.interests = field.stringValue.components(separatedBy:",").map { $0.trimmingCharacters(in:.whitespacesAndNewlines) };self.store.value = value;self.changed(value)
        }
        let setup = NSButton(title:"Set Up ChatGPT…",target:nil,action:nil)
        row("AI notebook",control:setup) { [weak self] _ in self?.activateHelper() }
        let sources = NSButton(title:"View Sources & Credits…",target:nil,action:nil)
        row("Archive",control:sources) { [weak self] _ in self?.showSources() }
        let days = archive?.load() ?? [], last = days.last?.date ?? "starter notebook"
        note("Latest saved day: \(last). Playback is offline. The helper adds new days using your ChatGPT account only after explicit setup.",height:52)
    }
    override func settingsDidChange() {
        guard let archive else { return }
        let url = archive.root.appendingPathComponent("preferences.json")
        // Only bridge settings after explicit setup created the helper preferences.
        guard FileManager.default.fileExists(atPath:url.path) else { return }
        do { try JSONEncoder().encode(store.value.commonplace.sanitized()).write(to:url,options:.atomic) }
        catch { showError(error.localizedDescription) }
    }
    override func dismiss(returnCode:NSApplication.ModalResponse) { sourcesWindow?.close();sourcesWindow = nil;super.dismiss(returnCode:returnCode) }
    private func showSources() {
        let library = CommonplaceLibrary(archive:archive)
        var credits = "COMMONPLACE — SOURCES & CREDITS\n\nNotebook passages and original study diagrams are fictional, including the starter notebook. Generated search ideas are never presented as verified quotations or historical facts.\n\n"
        for item in library.artifacts.map({ $0.0 }) { credits += item.attribution+"\n"+item.sourceURL.absoluteString+"\n"+item.licenseURL.absoluteString+"\n\n" }
        credits += "VERIFIED PUBLIC-DOMAIN EXTRACTS\n\n"
        for quote in CommonplaceQuotation.verified { credits += quote.attribution+"\n"+quote.source.absoluteString+"\n\n" }
        let panel = NSWindow(contentRect:NSRect(x:0,y:0,width:620,height:460),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        panel.title = "Commonplace Sources";panel.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame:panel.contentView!.bounds);scroll.autoresizingMask = [.width,.height];scroll.hasVerticalScroller = true
        let text = NSTextView(frame:scroll.bounds);text.isEditable = false;text.isSelectable = true;text.font = .systemFont(ofSize:13);text.textContainerInset = CGSize(width:20,height:20);text.string = credits;text.isVerticallyResizable = true;text.autoresizingMask = [.width];text.textContainer?.widthTracksTextView = true
        scroll.documentView = text;panel.contentView?.addSubview(scroll);sourcesWindow = panel;panel.center();panel.makeKeyAndOrderFront(nil)
    }
    private func activateHelper() {
        do {
            let archive = CommonplaceArchive()
            let lock = try archive.acquireGenerationLease();defer { withExtendedLifetime(lock) {} }
            try JSONEncoder().encode(store.value.commonplace.sanitized()).write(to:archive.root.appendingPathComponent("preferences.json"),options:.atomic)
        } catch { showError(error.localizedDescription);return }
        let installed = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Screensavers AI Helper.app")
        let sibling = Bundle(for:CommonplaceScene.self).bundleURL.deletingLastPathComponent().appendingPathComponent("Screensavers AI Helper.app")
        guard let url = [installed,sibling].first(where:{ Bundle(url:$0)?.bundleIdentifier == "com.someoneintexas.screensavers.aihelper" }) else {
            showError("Install the separate AI pack to add Screensavers AI Helper. Commonplace continues to work offline.");return
        }
        let configuration = NSWorkspace.OpenConfiguration();configuration.arguments = ["--ai-saver",SaverKind.commonplace.identifier]
        NSWorkspace.shared.openApplication(at:url,configuration:configuration) { [weak self] _,error in
            if let error { DispatchQueue.main.async { self?.showError(error.localizedDescription) } }
        }
    }
    private func showError(_ message:String) { let alert = NSAlert();alert.messageText = "Commonplace setup";alert.informativeText = message;if let window { alert.beginSheetModal(for:window) } }
}
