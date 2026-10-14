import Foundation

/// Only explicitly activated AI savers may use this separate process.
enum AIActivation {
    static let saverIdentifiers: Set<String> = ["com.someoneintexas.screensavers.commonplace"]
    static func isAllowed(arguments: [String]) -> Bool {
        if arguments == ["--developer-test"] { return true }
        return arguments.count == 2 && arguments[0] == "--ai-saver" && saverIdentifiers.contains(arguments[1])
    }
}

final class HelperSession {
    enum State: Equatable { case disconnected, connecting, signedOut, signingIn, signedIn, generating }
    private(set) var state = State.disconnected
    private(set) var status = "Connect when you want to add AI content."
    private(set) var sample = ""
    private(set) var loginID: String?
    private var completion: ((Result<String, Error>) -> Void)?
    private var outputLimit = 4096
    private var threadID: String?
    private var epoch = 0
    private let connection: CodexConnection
    private let workspace: URL
    private let openBrowser: (URL) -> Bool
    var changed: (() -> Void)?
    init(connection: CodexConnection, workspace: URL, openBrowser: @escaping (URL) -> Bool) {
        self.connection = connection; self.workspace = workspace; self.openBrowser = openBrowser
        connection.notification = { [weak self] method, params in self?.receive(method, params) }
        connection.disconnected = { [weak self] in
            self?.finish(.failure(NSError(domain:"Commonplace",code:1,userInfo:[NSLocalizedDescriptionKey:"Codex disconnected."])))
            self?.set(.disconnected, "Codex stopped. Reopen the helper to reconnect.")
        }
    }
    private func set(_ state: State, _ status: String) { self.state = state; self.status = status; changed?() }
    func connect() {
        guard state == .disconnected else { return }
        set(.connecting, "Connecting to local Codex…")
        connection.start { [weak self] result in
            guard let self, self.state == .connecting else { return }
            switch result {
            case .success: self.readAccount()
            case .failure(let error): self.set(.disconnected, error.localizedDescription)
            }
        }
    }
    private func readAccount() {
        connection.request("account/read", ["refreshToken": false]) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let value):
                let account = value["account"] as? [String: Any]
                self.set(account?["type"] as? String == "chatgpt" ? .signedIn : .signedOut,
                         account?["type"] as? String == "chatgpt" ? "Connected with ChatGPT. Generation uses your account limits." : "Continue with ChatGPT to add AI content.")
            case .failure(let error): self.set(.signedOut, error.localizedDescription)
            }
        }
    }
    static func trustedLoginURL(_ value: String) -> URL? {
        guard let url = URL(string: value), url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, ["auth.openai.com", "chatgpt.com"].contains(url.host?.lowercased() ?? "") else { return nil }
        return url
    }
    func login() {
        guard state == .signedOut else { return }; epoch += 1; let attempt = epoch
        set(.signingIn, "Finish signing in in your browser.")
        connection.request("account/login/start", ["type": "chatgpt"]) { [weak self] result in
            guard let self else { return }
            guard self.epoch == attempt else {
                if case .success(let value) = result, let id = value["loginId"] as? String {
                    self.connection.request("account/login/cancel", ["loginId": id]) { _ in }
                }
                return
            }
            switch result {
            case .success(let value):
                guard let id = value["loginId"] as? String else { self.set(.signedOut, "Codex did not return a login ID."); return }
                self.loginID = id
                guard let raw = value["authUrl"] as? String, let url = Self.trustedLoginURL(raw), self.openBrowser(url) else {
                    self.cancel(); self.set(.signedOut, "Could not open a trusted ChatGPT sign-in page. Please retry."); return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
                    guard let self, self.epoch == attempt, self.state == .signingIn else { return }
                    self.cancel(); self.set(.signedOut, "Sign-in timed out. Please retry.")
                }
            case .failure(let error): self.set(.signedOut, error.localizedDescription)
            }
        }
    }
    func cancel() {
        finish(.failure(NSError(domain:"Commonplace",code:5,userInfo:[NSLocalizedDescriptionKey:"Generation cancelled."])))
        epoch += 1
        if let id = loginID { connection.request("account/login/cancel", ["loginId": id]) { _ in } }
        loginID = nil
        if state == .generating {
            // Closing the dedicated child cancels even a turn whose ID hasn't arrived.
            connection.close(); threadID = nil; sample = ""
            set(.disconnected, "Generation cancelled. Reopen the helper to reconnect.")
        } else { set(.signedOut, "Sign-in cancelled.") }
    }
    func logout() {
        guard state == .signedIn else { return }
        sample = ""; set(.connecting, "Signing out…")
        connection.request("account/logout") { [weak self] result in
            switch result {
            case .success: self?.set(.signedOut, "Signed out of the helper.")
            case .failure(let error): self?.set(.signedIn, error.localizedDescription)
            }
        }
    }
    static func threadParameters(workspace: URL) -> [String: Any] {
        ["cwd": workspace.path, "ephemeral": true, "approvalPolicy": "never", "sandbox": "read-only",
         "baseInstructions": "Write short plain text for a screen saver. Do not use tools, inspect files, browse, or run commands.",
         "config": ["web_search": "disabled", "features": ["shell_tool": false, "apps": false, "code_mode": ["enabled": false]]]]
    }
    private func finish(_ result: Result<String,Error>) {
        let callback = completion; completion = nil; callback?(result)
    }
    func generateSample() {
        generate(prompt:"Write one original calming sentence about the night sky, under 25 words. Return only the sentence.",maximumBytes:4096,completion:{ _ in })
    }
    func generate(prompt: String, maximumBytes: Int = 160_000, completion: @escaping (Result<String,Error>) -> Void) {
        guard state == .signedIn else { completion(.failure(NSError(domain:"Commonplace",code:2,userInfo:[NSLocalizedDescriptionKey:"Sign in before generating."]))); return }
        self.completion = completion;outputLimit = min(160_000,max(1,maximumBytes))
        epoch += 1; let attempt = epoch; sample = ""
        set(.generating, "Writing notebook content…")
        let params = Self.threadParameters(workspace: workspace)
        connection.request("thread/start", params) { [weak self] result in
            guard let self, self.epoch == attempt, self.state == .generating else { return }
            switch result {
            case .success(let value):
                guard let thread = value["thread"] as? [String: Any], let id = thread["id"] as? String else { self.finish(.failure(NSError(domain:"Commonplace",code:3,userInfo:[NSLocalizedDescriptionKey:"Missing thread."]))); self.set(.signedIn, "Codex did not return a thread."); return }
                self.threadID = id
                self.connection.request("turn/start", ["threadId": id, "input": [["type": "text", "text": prompt]]]) { [weak self] result in
                    guard let self, self.epoch == attempt else { return }
                    if case .failure(let error) = result { self.threadID = nil; self.finish(.failure(error)); self.set(.signedIn, error.localizedDescription) }
                }
            case .failure(let error): self.finish(.failure(error)); self.set(.signedIn, error.localizedDescription)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            guard let self, self.epoch == attempt, self.state == .generating else { return }
            self.cancel(); self.set(.disconnected, "Generation timed out. Reopen the helper to retry.")
        }
    }
    private func receive(_ method: String, _ params: [String: Any]) {
        if method == "account/login/completed", state == .signingIn, let id = loginID, params["loginId"] as? String == id {
            loginID = nil; epoch += 1
            if params["success"] as? Bool == true { readAccount() }
            else { set(.signedOut, "Sign-in was not completed. Please retry.") }
        } else if method == "account/updated", params["authMode"] is NSNull {
            if state == .generating { cancel() }
            if state != .disconnected { set(.signedOut, "Please reconnect with ChatGPT.") }
        } else if state == .generating, let id = threadID, params["threadId"] as? String == id {
            if method == "item/completed", let item = params["item"] as? [String: Any], item["type"] as? String == "agentMessage", let text = item["text"] as? String {
                guard text.utf8.count <= outputLimit else { cancel(); return }
                sample = text; changed?()
            } else if method == "turn/completed", let turn = params["turn"] as? [String: Any] {
                threadID = nil; epoch += 1
                if turn["status"] as? String == "completed", !sample.isEmpty { finish(.success(sample)); set(.signedIn, "Generation complete.") }
                else { sample = ""; finish(.failure(NSError(domain:"Commonplace",code:4,userInfo:[NSLocalizedDescriptionKey:"Generation did not complete."]))); set(.signedIn, "Generation did not complete. Check your connection and account limits, then retry.") }
            }
        }
    }
    func close() { finish(.failure(NSError(domain:"Commonplace",code:6,userInfo:[NSLocalizedDescriptionKey:"Helper closed."]))); epoch += 1; loginID = nil; threadID = nil; connection.close() }
}
