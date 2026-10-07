import AppKit
import ServiceManagement

final class HelperDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var session: HelperSession?
    private let notebook = CommonplaceCoordinator()
    private var dailyTimer: Timer?
    private var lastAttemptDay = ""
    private let preferences = UserDefaults(suiteName:"com.someoneintexas.screensavers.aihelper")!
    private let daily = NSButton(checkboxWithTitle:"Add one notebook day automatically each day",target:nil,action:nil)
    private let loginItem = NSButton(checkboxWithTitle:"Keep the helper available after login",target:nil,action:nil)
    private let reset = NSButton(title:"Start a New Notebook…",target:nil,action:nil)
    private let export = NSButton(title:"Export Metadata…",target:nil,action:nil)
    private let reveal = NSButton(title:"Show Local Archive",target:nil,action:nil)
    private var production = false
    private var commonplaceSettings: CommonplaceSettings {
        let url = CommonplaceArchive.applicationURL.appendingPathComponent("preferences.json")
        guard let values = try? url.resourceValues(forKeys:[.fileSizeKey,.isSymbolicLinkKey]),values.isSymbolicLink != true,(values.fileSize ?? Int.max)<10000,let data = try? Data(contentsOf:url),data.count<10000,let value = try? JSONDecoder().decode(CommonplaceSettings.self,from:data) else { return CommonplaceSettings() }
        return value.sanitized()
    }
    private let status = NSTextField(wrappingLabelWithString: "")
    private let sample = NSTextField(wrappingLabelWithString: "")
    private let login = NSButton(title: "Continue with ChatGPT", target: nil, action: nil)
    private let test = NSButton(title: "Generate Test Content", target: nil, action: nil)
    private let cancel = NSButton(title: "Cancel", target: nil, action: nil)
    private let logout = NSButton(title: "Sign Out", target: nil, action: nil)
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 640), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Screensavers AI Helper"; window.delegate = self; window.center()
        let menu = NSMenu(); let item = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit AI Helper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu; menu.addItem(item); NSApp.mainMenu = menu
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.frame = NSRect(x: 28, y: 25, width: 564, height: 590); stack.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(stack)
        let title = NSTextField(labelWithString: "Optional AI content"); title.font = .boldSystemFont(ofSize: 22); stack.addArrangedSubview(title)
        stack.addArrangedSubview(status)
        let arguments = Array(CommandLine.arguments.dropFirst())
        production = arguments != ["--developer-test"]
        let activated = AIActivation.isAllowed(arguments:arguments)
        if activated && production { preferences.set(true,forKey:"CommonplaceEnabled") }
        let allowed = activated || (arguments.isEmpty && preferences.bool(forKey:"CommonplaceEnabled"))
        if allowed {
            let note = NSTextField(wrappingLabelWithString: production ? "Commonplace sends your selected interests and a compact memory of its own fictional notebook to OpenAI using local Codex and your ChatGPT account limits. It does not read your documents, browser history or screen. The screensaver reads saved pages offline." : "Developer test: sends one fixed prompt using local Codex and your ChatGPT account limits.")
            stack.addArrangedSubview(note)
            let row = NSStackView(views: [login, test]); row.spacing = 12; stack.addArrangedSubview(row)
            let controls = NSStackView(views: [cancel, logout]); controls.spacing = 12; stack.addArrangedSubview(controls)
            for button in [login, test, cancel, logout] { button.bezelStyle = .rounded; button.target = self; button.isEnabled = false }
            login.action = #selector(signIn); test.action = #selector(generate); cancel.action = #selector(cancelAction); logout.action = #selector(signOut)
            if production {
                title.stringValue = "Commonplace notebook"
                test.title = "Generate Missing Day"
                daily.state = preferences.object(forKey:"DailyGeneration") == nil || preferences.bool(forKey:"DailyGeneration") ? .on:.off
                loginItem.state = SMAppService.mainApp.status == .enabled ? .on:.off
                daily.target = self;daily.action = #selector(dailyChanged)
                loginItem.target = self;loginItem.action = #selector(loginItemChanged)
                reset.target = self;reset.action = #selector(resetNotebook)
                reveal.target = self;reveal.action = #selector(showArchive)
                stack.addArrangedSubview(daily);stack.addArrangedSubview(loginItem)
                export.target = self;export.action = #selector(exportMetadata)
                stack.addArrangedSubview(NSStackView(views:[reset,reveal,export]))
                notebook.changed = { [weak self] in self?.refresh() }
                dailyTimer = Timer.scheduledTimer(withTimeInterval:60,repeats:true) { [weak self] _ in self?.generateDailyIfNeeded() }
            }
            stack.addArrangedSubview(sample)
            if let executable = CodexProcess.findExecutable() {
                let home = CodexProcess.applicationHome
                let connection = CodexConnection(transport: CodexProcess(executable: executable, home: home))
                session = HelperSession(connection: connection, workspace: home.appendingPathComponent("workspace"), openBrowser: { NSWorkspace.shared.open($0) })
                session?.changed = { [weak self] in self?.refresh() }
                session?.connect()
            } else { status.stringValue = "Install the Codex CLI, then reopen this helper. See docs/AI_HELPER.md in the source repository. No screen saver is affected." }
        } else {
            status.stringValue = "Open Commonplace Options and choose Set Up ChatGPT to connect this helper. The standard collection works without AI."
        }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func refresh() {
        guard let session else { return }; status.stringValue = session.status; sample.stringValue = production ? notebook.status : session.sample
        login.isEnabled = session.state == .signedOut
        test.isEnabled = session.state == .signedIn; logout.isEnabled = session.state == .signedIn
        cancel.isEnabled = session.state == .signingIn || session.state == .generating
        reset.isEnabled = !notebook.busy
        if production, session.state == .signedIn { DispatchQueue.main.async { [weak self] in self?.generateDailyIfNeeded() } }
    }
    @objc private func signIn() { session?.login() }
    @objc private func generate() {
        guard let session else { return }
        if production { lastAttemptDay = CommonplaceArchive.dayKey(Date());notebook.generate(session:session,settings:commonplaceSettings) }
        else { session.generateSample() }
    }
    private func generateDailyIfNeeded() {
        guard production, let session, session.state == .signedIn, !notebook.busy else { return }
        let today = CommonplaceArchive.dayKey(Date())
        let first = notebook.archive.load().isEmpty
        guard (first || daily.state == .on),lastAttemptDay != today else { return }
        generate()
    }
    @objc private func dailyChanged() { preferences.set(daily.state == .on,forKey:"DailyGeneration");generateDailyIfNeeded() }
    @objc private func loginItemChanged() {
        do { if loginItem.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
        catch { status.stringValue = "Could not change login availability: "+error.localizedDescription }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on:.off
    }
    @objc private func resetNotebook() {
        let alert = NSAlert();alert.messageText = "Start a new Commonplace notebook?";alert.informativeText = "Your current notebook will remain in a saved archive folder. Five new opening days will be generated using your ChatGPT account.";alert.addButton(withTitle:"Start New Notebook");alert.addButton(withTitle:"Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try notebook.reset();lastAttemptDay = "";generate() } catch { status.stringValue = error.localizedDescription }
    }
    @objc private func exportMetadata() {
        let panel = NSSavePanel();panel.nameFieldStringValue = "Commonplace-metadata.json";panel.canCreateDirectories = true
        panel.beginSheetModal(for:window) { [weak self] result in
            guard let self,result == .OK,let url = panel.url else { return }
            do {
                let files = self.notebook.archive.files()
                let days = try files.flatMap { file -> [[String:Any]] in
                    let batch = try JSONDecoder().decode(CommonplaceBundle.self,from:Data(contentsOf:file))
                    return batch.days.map { ["date":$0.date,"title":$0.title,"entryIDs":$0.entries.map(\.id)] }
                }
                let sourceDirectory = self.notebook.archive.root.appendingPathComponent("sources")
                let metadata = (try? FileManager.default.contentsOfDirectory(at:sourceDirectory,includingPropertiesForKeys:nil)) ?? []
                var sources:[[String:Any]] = []
                if let bundled = Bundle.main.url(forResource:"Commonplace-catalog",withExtension:"json"),let data = try? Data(contentsOf:bundled),let items = try? JSONSerialization.jsonObject(with:data) as? [[String:Any]] { sources += items }
                for file in metadata where file.pathExtension == "json" {
                    if let data = try? Data(contentsOf:file),data.count<12000,let item = try? JSONDecoder().decode(CommonplaceArtifact.self,from:data),item.reusable,let value = try? JSONSerialization.jsonObject(with:data) as? [String:Any] { sources.append(value) }
                }
                let object:[String:Any] = ["schemaVersion":1,"days":days,"sources":sources,"quotations":CommonplaceQuotation.verified.map { ["attribution":$0.attribution,"sourceURL":$0.source.absoluteString] }]
                try JSONSerialization.data(withJSONObject:object,options:[.prettyPrinted,.sortedKeys]).write(to:url,options:.atomic)
                self.status.stringValue = "Archive metadata exported."
            } catch { self.status.stringValue = error.localizedDescription }
        }
    }
    @objc private func showArchive() { NSWorkspace.shared.open(notebook.archive.root) }
    @objc private func cancelAction() { session?.cancel() }
    @objc private func signOut() { session?.logout() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { window.makeKeyAndOrderFront(nil); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !production || daily.state != .on }
    func applicationWillTerminate(_ notification: Notification) { dailyTimer?.invalidate();session?.close() }
}

let app = NSApplication.shared
let delegate = HelperDelegate(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
