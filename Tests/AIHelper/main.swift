import Foundation

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
func wait(_ predicate: () -> Bool, timeout: Double = 3) {
    let deadline = Date().addingTimeInterval(timeout)
    while !predicate() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
}
final class FakeTransport: CodexTransport {
    var receive: (([String: Any]) -> Void)?
    var ended: (() -> Void)?
    var messages: [[String: Any]] = []
    var stopped = false
    func start() throws {}
    func send(_ message: [String: Any]) throws { messages.append(message) }
    func stop() { stopped = true }
    func respond(_ result: [String: Any]) { receive?(["id": messages.last!["id"]!, "result": result]) }
    func notify(_ method: String, _ params: [String: Any]) { receive?(["method": method, "params": params]) }
    var method: String? { messages.last?["method"] as? String }
}

expect(!AIActivation.isAllowed(arguments: []), "ordinary launch does not offer sign-in")
for id in ["worldclockroom", "citydrift", "voxelcosmos", "papersky", "dapple", "flourish", "lattice", "strawberryfieldsforever", "goodresearchtakestime", "unknown"] {
    expect(!AIActivation.isAllowed(arguments: ["--ai-saver", "com.someoneintexas.screensavers." + id]), "existing/unknown savers cannot activate AI")
}
expect(AIActivation.isAllowed(arguments: ["--developer-test"]), "explicit developer test works")
for url in ["http://auth.openai.com/x", "https://auth.openai.com.evil.test/", "https://evil.test/", "https://user@auth.openai.com/", "file:///tmp/login", "https://chatgpt.com:444/"] {
    expect(HelperSession.trustedLoginURL(url) == nil, "reject untrusted login URL")
}
expect(HelperSession.trustedLoginURL("https://auth.openai.com/oauth/authorize?a=b") != nil, "accept documented auth host")
let fake = FakeTransport(), workspace = URL(fileURLWithPath: "/tmp/helper-tests")
let connection = CodexConnection(transport: fake)
var opened: [URL] = []
let session = HelperSession(connection: connection, workspace: workspace, openBrowser: { opened.append($0); return true })
session.generateSample(); session.login(); expect(fake.messages.isEmpty, "no operations before user connects")
session.connect(); expect(fake.method == "initialize", "initialize first")
fake.respond([:]); expect(fake.messages[1]["method"] as? String == "initialized" && fake.method == "account/read", "handshake before account read")
fake.respond(["account": NSNull()]); expect(session.state == .signedOut, "signed out state")
session.generateSample(); expect(fake.method == "account/read", "no unauthenticated generation")
session.login(); expect(fake.method == "account/login/start", "managed ChatGPT login")
fake.respond(["loginId": "a", "authUrl": "https://auth.openai.com/oauth/authorize"])
expect(opened.count == 1 && session.state == .signingIn, "explicit login opens browser")
fake.notify("account/login/completed", ["loginId": "stale", "success": true]); expect(session.state == .signingIn, "ignore unrelated login notification")
session.cancel(); expect(fake.method == "account/login/cancel" && session.state == .signedOut, "cancel managed login")
fake.respond([:]); fake.notify("account/login/completed", ["loginId": "a", "success": true]); expect(session.state == .signedOut, "late login cannot reconnect")
session.login(); session.cancel()
fake.respond(["loginId": "late", "authUrl": "https://auth.openai.com/oauth/authorize"])
expect(fake.method == "account/login/cancel" && opened.count == 1, "cancel before login response never opens browser")
fake.respond([:])
session.login(); fake.respond(["loginId": "bad", "authUrl": "https://evil.test/"])
expect(session.state == .signedOut && fake.method == "account/login/cancel" && opened.count == 1, "invalid auth URL cancels flow")
fake.respond([:])
session.login(); fake.respond(["loginId": "b", "authUrl": "https://auth.openai.com/oauth/authorize"])
fake.notify("account/login/completed", ["loginId": "b", "success": true]); expect(fake.method == "account/read", "verify account after OAuth")
fake.respond(["account": ["type": "chatgpt"]]); expect(session.state == .signedIn, "ChatGPT account verified")
session.generateSample(); expect(fake.method == "thread/start", "generation is explicit")
let params = fake.messages.last!["params"] as! [String: Any]
expect(params["sandbox"] as? String == "read-only" && params["approvalPolicy"] as? String == "never" && params["ephemeral"] as? Bool == true, "bounded ephemeral read-only generation")
fake.respond(["thread": ["id": "thread-1"]]); expect(fake.method == "turn/start", "test prompt sent after thread")
fake.respond(["turn": ["id": "turn-1"]])
fake.notify("item/completed", ["threadId": "other", "item": ["type": "agentMessage", "text": "wrong"]]); expect(session.sample.isEmpty, "ignore unrelated content")
fake.notify("item/completed", ["threadId": "thread-1", "item": ["type": "agentMessage", "text": "A quiet night."]])
fake.notify("turn/completed", ["threadId": "thread-1", "turn": ["status": "completed"]])
expect(session.state == .signedIn && session.sample == "A quiet night.", "successful sample completion")
fake.receive?(["method": "item/commandExecution/requestApproval", "id": "server-request", "params": [:]])
expect(fake.messages.last?["error"] != nil, "never grant tool or command approvals")
session.generateSample(); fake.respond(["thread": ["id": "thread-2"]]); fake.respond(["turn": ["id": "turn-2"]])
fake.notify("item/completed", ["threadId": "thread-2", "item": ["type": "agentMessage", "text": "Incomplete"]])
fake.notify("turn/completed", ["threadId": "thread-2", "turn": ["status": "failed", "error": ["message": "quota"]]])
expect(session.state == .signedIn && session.sample.isEmpty, "failed or quota-limited generation never keeps partial content")
session.generateSample(); fake.receive?(["id": fake.messages.last!["id"]!, "error": ["code": -1, "message": "offline"]])
expect(session.state == .signedIn && session.sample.isEmpty, "thread failure is recoverable without automatic retries")
session.logout(); fake.respond([:]); expect(session.state == .signedOut && session.sample.isEmpty, "sign out clears sample")
session.login(); fake.respond(["loginId": "failed", "authUrl": "https://auth.openai.com/oauth/authorize"])
fake.notify("account/login/completed", ["loginId": "failed", "success": false])
expect(session.state == .signedOut, "failed login restores sign-in action")
var timedOut = false
connection.request("test/timeout", timeout: 0.01) { if case .failure = $0 { timedOut = true } }
wait { timedOut }; expect(timedOut, "RPC deadline")
var disconnected = false
connection.request("test/exit") { if case .failure = $0 { disconnected = true } }
fake.ended?(); expect(disconnected && fake.stopped && session.state == .disconnected, "child exit resolves requests and UI")

// Closing/cancelling during generation must stop its private child, even before a turn ID.
let cancelling = FakeTransport(), cancellingConnection = CodexConnection(transport: cancelling)
let cancellingSession = HelperSession(connection: cancellingConnection, workspace: workspace, openBrowser: { _ in false })
cancellingSession.connect(); cancelling.respond([:]); cancelling.respond(["account": ["type": "chatgpt"]])
cancellingSession.generateSample(); cancelling.respond(["thread": ["id": "cancelled-thread"]])
cancellingSession.cancel()
expect(cancelling.stopped && cancellingSession.state == .disconnected, "generation cancellation stops child before turn response")
cancelling.notify("item/completed", ["threadId": "cancelled-thread", "item": ["type": "agentMessage", "text": "late"]])
expect(cancellingSession.sample.isEmpty, "closed connection drops late notifications")
let missingHome = FileManager.default.temporaryDirectory.appendingPathComponent("screensavers-missing-" + UUID().uuidString)
defer { try? FileManager.default.removeItem(at: missingHome) }
let missing = CodexConnection(transport: CodexProcess(executable: URL(fileURLWithPath: "/nonexistent-codex"), home: missingHome))
var missingFailed = false
missing.start { if case .failure = $0 { missingFailed = true } }
expect(missingFailed, "missing Codex is a recoverable launch error")
missing.close()

if CommandLine.arguments.contains("--protocol-smoke") {
    guard let executable = CodexProcess.findExecutable() else { fputs("Codex CLI required for protocol smoke.\n", stderr); exit(1) }
    let home = FileManager.default.temporaryDirectory.appendingPathComponent("screensavers-ai-smoke-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    let live = CodexConnection(transport: CodexProcess(executable: executable, home: home))
    var done = false, success = false
    live.start { result in
        if case .success = result {
            live.request("account/read", ["refreshToken": false]) { result in
                guard case .success(let object) = result, object["account"] is NSNull else { done = true; return }
                live.request("thread/start", HelperSession.threadParameters(workspace: home.appendingPathComponent("workspace"))) { result in
                    if case .success(let object) = result { success = (object["thread"] as? [String: Any])?["id"] is String }
                    done = true
                }
            }
        } else { done = true }
    }
    wait({ done }, timeout: 25); live.close()
    expect(done && success, "real CLI handshake, isolated signed-out account and thread policy, no browser or generation")
}
print("Passed \(checks) AI helper checks.")
