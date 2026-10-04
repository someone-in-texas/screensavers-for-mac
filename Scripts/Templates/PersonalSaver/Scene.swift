import AppKit

/// Edit this file for your own artwork. Keep all geometry relative to size.
final class PersonalScene {
    private var previous: Double?
    private(set) var elapsed = 0.0
    func start() { previous = nil }
    func stop() { previous = nil }
    func draw(in context: CGContext, size: CGSize, time: Double) {
        if let previous { elapsed += min(1.0 / 15, max(0, time - previous)) }
        previous = time
        context.setFillColor(NSColor(calibratedWhite: 0.06, alpha: 1).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        let radius = min(size.width, size.height) * 0.09
        let center = CGPoint(x: size.width * (0.5 + 0.22 * sin(elapsed / 9)),
                             y: size.height * (0.5 + 0.18 * cos(elapsed / 13)))
        context.setFillColor(NSColor.systemTeal.cgColor)
        context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
