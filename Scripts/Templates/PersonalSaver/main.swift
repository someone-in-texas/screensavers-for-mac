import AppKit

final class Preview: NSView {
    let scene = PersonalScene()
    override var isOpaque: Bool { true }
    override func draw(_ rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        scene.draw(in: context, size: bounds.size, time: ProcessInfo.processInfo.systemUptime)
    }
}
if CommandLine.arguments.contains("--smoke") {
    let scene = PersonalScene(); scene.start()
    for size in [CGSize(width: 280, height: 180), CGSize(width: 1600, height: 900), CGSize(width: 900, height: 1600)] {
        let c = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        scene.draw(in: c, size: size, time: 0); scene.draw(in: c, size: size, time: 1.0 / 30)
        precondition(c.makeImage() != nil)
    }
    scene.stop(); let elapsed = scene.elapsed; scene.start()
    let c = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    scene.draw(in: c, size: CGSize(width: 100, height: 100), time: 1000)
    precondition(scene.elapsed == elapsed, "Stopped time must not advance animation")
    print("Personal saver smoke passed.")
} else {
    let app = NSApplication.shared; app.setActivationPolicy(.regular)
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    window.title = "__TITLE__ — Preview"; window.center()
    let view = Preview(frame: window.contentView!.bounds); view.autoresizingMask = [.width, .height]
    window.contentView = view; view.scene.start()
    let menu = NSMenu(); let item = NSMenuItem(); let submenu = NSMenu()
    submenu.addItem(withTitle: "Quit Preview", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    item.submenu = submenu; menu.addItem(item); app.mainMenu = menu
    let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { _ in
        if !window.isVisible { view.scene.stop(); NSApp.terminate(nil) }
        view.needsDisplay = true
    }
    RunLoop.main.add(timer, forMode: .common)
    window.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true); app.run()
}
