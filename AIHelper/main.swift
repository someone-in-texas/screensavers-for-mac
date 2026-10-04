import AppKit

final class HelperDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var session: HelperSession?
    private let status = NSTextField(wrappingLabelWithString: "")
    private let sample = NSTextField(wrappingLabelWithString: "")
    private let login = NSButton(title: "Continue with ChatGPT", target: nil, action: nil)
    private let test = NSButton(title: "Generate Test Content", target: nil, action: nil)
    private let cancel = NSButton(title: "Cancel", target: nil, action: nil)
    private let logout = NSButton(title: "Sign Out", target: nil, action: nil)
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 340), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Screensavers AI Helper"; window.delegate = self; window.center()
        let menu = NSMenu(); let item = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit AI Helper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu; menu.addItem(item); NSApp.mainMenu = menu
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 18
        stack.frame = NSRect(x: 28, y: 25, width: 504, height: 290); stack.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(stack)
        let title = NSTextField(labelWithString: "Optional AI content"); title.font = .boldSystemFont(ofSize: 22); stack.addArrangedSubview(title)
        stack.addArrangedSubview(status)
        let allowed = AIActivation.isAllowed(arguments: Array(CommandLine.arguments.dropFirst()))
        if allowed {
            let note = NSTextField(wrappingLabelWithString: "Uses local Codex and your ChatGPT account. Test generation sends a fixed prompt to OpenAI and uses your account limits. Existing screen savers never require this helper.")
            stack.addArrangedSubview(note)
            let row = NSStackView(views: [login, test]); row.spacing = 12; stack.addArrangedSubview(row)
            let controls = NSStackView(views: [cancel, logout]); controls.spacing = 12; stack.addArrangedSubview(controls)
            for button in [login, test, cancel, logout] { button.bezelStyle = .rounded; button.target = self; button.isEnabled = false }
            login.action = #selector(signIn); test.action = #selector(generate); cancel.action = #selector(cancelAction); logout.action = #selector(signOut)
            stack.addArrangedSubview(sample)
            if let executable = CodexProcess.findExecutable() {
                let home = CodexProcess.applicationHome
                let connection = CodexConnection(transport: CodexProcess(executable: executable, home: home))
                session = HelperSession(connection: connection, workspace: home.appendingPathComponent("workspace"), openBrowser: { NSWorkspace.shared.open($0) })
                session?.changed = { [weak self] in self?.refresh() }
                session?.connect()
            } else { status.stringValue = "Install the Codex CLI, then reopen this helper. See docs/AI_HELPER.md in the source repository. No screen saver is affected." }
        } else {
            status.stringValue = "All nine current screen savers work without AI. There is nothing to connect. Future AI-enabled savers will open setup here when needed."
        }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func refresh() {
        guard let session else { return }; status.stringValue = session.status; sample.stringValue = session.sample
        login.isEnabled = session.state == .signedOut
        test.isEnabled = session.state == .signedIn; logout.isEnabled = session.state == .signedIn
        cancel.isEnabled = session.state == .signingIn || session.state == .generating
    }
    @objc private func signIn() { session?.login() }
    @objc private func generate() { session?.generateSample() }
    @objc private func cancelAction() { session?.cancel() }
    @objc private func signOut() { session?.logout() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { session?.close() }
}

let app = NSApplication.shared
let delegate = HelperDelegate(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
