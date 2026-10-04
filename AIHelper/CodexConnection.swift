import Foundation

/// A private stdio child, never a network listener. All client callbacks use main.
protocol CodexTransport: AnyObject {
    var receive: (([String: Any]) -> Void)? { get set }
    var ended: (() -> Void)? { get set }
    func start() throws
    func send(_ message: [String: Any]) throws
    func stop()
}

struct HelperError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class CodexProcess: CodexTransport {
    var receive: (([String: Any]) -> Void)?
    var ended: (() -> Void)?
    private let executable: URL, home: URL
    private let process = Process(), input = Pipe(), output = Pipe()
    private var stopped = false
    init(executable: URL, home: URL) { self.executable = executable; self.home = home }
    static func findExecutable() -> URL? {
        // Finder does not inherit the shell's PATH. Never download or run a shell.
        let paths = ["/opt/homebrew/bin/codex", "/usr/local/bin/codex"] +
            (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").filter { $0.hasPrefix("/") }.map { String($0) + "/codex" }
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }.map { URL(fileURLWithPath: $0) }
    }
    static var applicationHome: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Screensavers for Mac/AI Helper", isDirectory: true)
    }
    func start() throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let workspace = home.appendingPathComponent("workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        process.executableURL = executable
        process.arguments = ["app-server", "--listen", "stdio://", "-c", "cli_auth_credentials_store=\"keyring\"",
                             "-c", "analytics.enabled=false", "-c", "feedback.enabled=false"]
        // Do not inherit API keys, the developer's CODEX_HOME, or project config.
        var environment: [String: String] = [:]
        for key in ["HOME", "USER", "LOGNAME", "PATH", "TMPDIR", "LANG"] {
            environment[key] = ProcessInfo.processInfo.environment[key]
        }
        environment["CODEX_HOME"] = home.path
        process.environment = environment; process.currentDirectoryURL = workspace
        process.standardInput = input; process.standardOutput = output
        process.standardError = FileHandle.nullDevice // Auth URLs/tokens must not enter application logs.
        try process.run()
        DispatchQueue.global(qos: .utility).async { [weak self, output] in
            var buffer = Data()
            while true {
                let data = output.fileHandleForReading.availableData
                if data.isEmpty { break }
                buffer.append(data)
                guard buffer.count <= 2_000_000 else { break }
                while let newline = buffer.firstIndex(of: 10) {
                    let line = buffer.prefix(upTo: newline); buffer.removeSubrange(...newline)
                    guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                        DispatchQueue.main.async { self?.stop(); self?.ended?() }; return
                    }
                    DispatchQueue.main.async { guard let self, !self.stopped else { return }; self.receive?(object) }
                }
            }
            DispatchQueue.main.async { guard let self, !self.stopped else { return }; self.stop(); self.ended?() }
        }
    }
    func send(_ message: [String: Any]) throws {
        guard process.isRunning, !stopped else { throw HelperError(message: "The Codex connection is closed.") }
        var data = try JSONSerialization.data(withJSONObject: message); data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
    }
    func stop() {
        guard !stopped else { return }; stopped = true
        try? input.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
            let child = process
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if child.isRunning { kill(child.processIdentifier, SIGKILL) } }
        }
    }
    deinit { stop() }
}

final class CodexConnection {
    typealias Reply = (Result<[String: Any], Error>) -> Void
    private let transport: CodexTransport
    private var nextID = 0
    private var pending: [Int: Reply] = [:]
    private var closed = false
    var notification: ((String, [String: Any]) -> Void)?
    var disconnected: (() -> Void)?
    init(transport: CodexTransport) {
        self.transport = transport
        transport.receive = { [weak self] in self?.receive($0) }
        transport.ended = { [weak self] in self?.close(); self?.disconnected?() }
    }
    func start(completion: @escaping Reply) {
        do { try transport.start() } catch { completion(.failure(error)); return }
        request("initialize", ["clientInfo": ["name": "screensavers_for_mac", "title": "Screensavers for Mac", "version": BuildVersion.value]]) { [weak self] result in
            if case .success = result { self?.send(["method": "initialized", "params": [:]]) }
            completion(result)
        }
    }
    func request(_ method: String, _ params: [String: Any] = [:], timeout: Double = 20, completion: @escaping Reply) {
        guard !closed else { completion(.failure(HelperError(message: "Connection closed. Reopen the helper to retry."))); return }
        nextID += 1; let id = nextID; pending[id] = completion
        do { try transport.send(["id": id, "method": method, "params": params]) }
        catch { pending.removeValue(forKey: id)?(.failure(error)); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.pending.removeValue(forKey: id)?(.failure(HelperError(message: "Codex did not respond in time. Please retry.")))
        }
    }
    private func send(_ object: [String: Any]) { do { try transport.send(object) } catch { close() } }
    private func receive(_ object: [String: Any]) {
        guard !closed else { return }
        if let method = object["method"] as? String {
            if let id = object["id"] {
                // Content generation never grants tool, shell, file or permission requests.
                send(["id": id, "error": ["code": -32601, "message": "This helper does not provide tools or approvals."]])
            } else { notification?(method, object["params"] as? [String: Any] ?? [:]) }
        } else if let id = object["id"] as? Int, let reply = pending.removeValue(forKey: id) {
            if object["error"] != nil { reply(.failure(HelperError(message: "Codex rejected the request. Check sign-in, account limits, and your Codex version."))) }
            else if let result = object["result"] as? [String: Any] { reply(.success(result)) }
            else { reply(.failure(HelperError(message: "Unexpected Codex response."))) }
        }
    }
    func close() {
        guard !closed else { return }; closed = true; transport.stop()
        let replies = pending.values; pending.removeAll()
        for reply in replies { reply(.failure(HelperError(message: "Connection closed."))) }
    }
    deinit { transport.stop() }
}
