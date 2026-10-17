import AppKit

/// Deliberately limited to public build and display information: no preferences,
/// account details, notebook content, filesystem paths, or network requests.
enum ConfigurationSupport {
    static func report(kind: SaverKind, version: String = BuildVersion.value,
                       os: String = ProcessInfo.processInfo.operatingSystemVersionString,
                       displaySize: CGSize?, scale: CGFloat?) -> String {
        var lines = ["Screensavers for Mac", "Saver: \(kind.title)", "Version: \(version)", "macOS: \(os)"]
        if let size = displaySize, let scale {
            lines.append("Options display: \(Int(size.width)) × \(Int(size.height)) points, \(String(format: "%.1f", Double(scale)))× scale")
        }
        return lines.joined(separator: "\n")
    }
}

final class ConfigurationSupportFooter: NSView {
    private let kind: SaverKind
    init(kind: SaverKind, frame: NSRect) {
        self.kind = kind
        super.init(frame: frame)
        let version = NSTextField(labelWithString: "Version \(BuildVersion.value)")
        version.font = .systemFont(ofSize: 11)
        version.textColor = .secondaryLabelColor
        version.frame = NSRect(x: 0, y: 3, width: 180, height: 18)
        addSubview(version)
        let copy = NSButton(title: "Copy Support Info", target: self, action: #selector(copySupport(_:)))
        copy.bezelStyle = .rounded
        copy.font = .systemFont(ofSize: 11)
        copy.frame = NSRect(x: frame.width - 160, y: 0, width: 160, height: 24)
        copy.toolTip = "Copy the saver name, loaded version, macOS version and Options display size. No personal settings or account information."
        addSubview(copy)
    }
    required init?(coder: NSCoder) { nil }
    @objc private func copySupport(_ sender: NSButton) {
        let screen = window?.screen
        let report = ConfigurationSupport.report(kind: kind, displaySize: screen?.frame.size, scale: screen?.backingScaleFactor)
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(report, forType: .string) {
            sender.title = "Copied"
        }
    }
}
