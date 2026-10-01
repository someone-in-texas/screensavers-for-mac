import AppKit
import QuartzCore

final class WorldClockScene: SaverScene {
    private var settings = SaverSettings()
    private var faces: [CGImage] = []
    private let calendars: [Calendar] = ClockCity.all.map { city in
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = city.zone; return calendar
    }
    private var motion = MotionClock()
    private let stage = CALayer()
    private let floorLayer = CALayer()
    private let shade = CAGradientLayer()
    private var renderedSize = CGSize.zero
    private var layerSettings: SaverSettings?
    private var layerHands: [(Int, CALayer, CALayer, CALayer)] = []
    private let padding: CGFloat = 120
    private var paintingStaticFloor = false
    func start() { motion.pause() }
    func stop() { motion.pause() }
    func apply(_ settings: SaverSettings) {
        if self.settings.face != settings.face || self.settings.labels != settings.labels || faces.isEmpty {
            self.settings = settings; makeFaces()
        }
        self.settings = settings
    }
    private func makeFaces() {
        faces = ClockCity.all.compactMap { city in
            guard let c = bitmap(width: 512, height: 512) else { return nil }
            c.scaleBy(x: 2, y: 2)
            c.setFillColor(settings.face.color.cgColor)
            c.fillEllipse(in: CGRect(x: 10, y: 10, width: 236, height: 236))
            c.setStrokeColor(NSColor.black.withAlphaComponent(0.18).cgColor); c.setLineWidth(1)
            c.strokeEllipse(in: CGRect(x: 16, y: 16, width: 224, height: 224))
            for tick in 0..<60 {
                let angle = Double(tick) / 60 * .pi * 2
                let outer = 103.0, inner = tick % 5 == 0 ? 92.0 : 99.0
                line(c, from: CGPoint(x: 128 + sin(angle) * inner, y: 128 + cos(angle) * inner),
                     to: CGPoint(x: 128 + sin(angle) * outer, y: 128 + cos(angle) * outer),
                     width: tick % 5 == 0 ? 2 : 0.8, color: NSColor(white: 0.12, alpha: tick % 5 == 0 ? 0.8 : 0.45).cgColor)
            }
            if settings.labels {
                withAppKit(c) {
                    let name = city.name.uppercased()
                    let font = NSFont.systemFont(ofSize: name.count > 11 ? 10 : 12, weight: .medium)
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(white: 0.16, alpha: 1), .kern: 1.2]
                    let label = NSAttributedString(string: name, attributes: attrs)
                    label.draw(at: CGPoint(x: 128 - label.size().width / 2, y: 76))
                    text("WORLD / LOCAL", at: CGPoint(x: 88, y: 60), size: 6.5, color: NSColor(white: 0.28, alpha: 1), tracking: 1)
                }
            }
            return c.makeImage()
        }
    }
    func updateLayer(_ root: CALayer, size: CGSize, time: Double, date: Date) -> Bool {
        let viewport = Mercator.renderSize(size)
        if stage.superlayer !== root {
            root.masksToBounds = true
            root.addSublayer(stage); stage.addSublayer(floorLayer); root.addSublayer(shade)
            shade.colors = [NSColor.black.withAlphaComponent(0).cgColor, NSColor.black.withAlphaComponent(0.4).cgColor]
            shade.startPoint = CGPoint(x: 0.5, y: 0); shade.endPoint = CGPoint(x: 0.5, y: 1)
        }
        if renderedSize != viewport || layerSettings?.floor != settings.floor || layerSettings?.face != settings.face || layerSettings?.labels != settings.labels || layerSettings?.density != settings.density {
            rebuildLayers(viewport: viewport, time: time, date: date)
            renderedSize = viewport; layerSettings = settings
        }
        motion.step(now: time, speed: settings.speed)
        let spacing = max(115, min(240, viewport.width / 6)) / settings.density
        let dx = sin(motion.elapsed / 130) * spacing * 0.35
        let dy = cos(motion.elapsed / 170) * spacing * 0.25
        let scale = size.width / viewport.width
        stage.anchorPoint = .zero
        stage.position = CGPoint(x: (dx - padding) * scale, y: (dy - padding) * scale)
        stage.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        shade.frame = CGRect(origin: .zero, size: size)
        let angles = calendars.map { HandAngles(date: date, calendar: $0, smooth: settings.smoothSeconds) }
        for (index, hour, minute, second) in layerHands {
            hour.setAffineTransform(CGAffineTransform(rotationAngle: -angles[index].hour))
            minute.setAffineTransform(CGAffineTransform(rotationAngle: -angles[index].minute))
            second.setAffineTransform(CGAffineTransform(rotationAngle: -angles[index].second))
        }
        return true
    }
    private func rebuildLayers(viewport: CGSize, time: Double, date: Date) {
        stage.sublayers?.filter { $0 !== floorLayer }.forEach { $0.removeFromSuperlayer() }
        layerHands.removeAll()
        let padded = CGSize(width: ceil(viewport.width + padding * 2), height: ceil(viewport.height + padding * 2))
        stage.bounds = CGRect(origin: .zero, size: padded)
        if let c = bitmap(width: Int(padded.width) * 2, height: Int(padded.height) * 2) {
            c.scaleBy(x: 2, y: 2)
            paintingStaticFloor = true
            draw(in: c, size: padded, time: time, date: date)
            paintingStaticFloor = false
            floorLayer.contents = c.makeImage(); floorLayer.frame = CGRect(origin: .zero, size: padded)
        }
        let spacing = max(115, min(240, viewport.width / 6)) / settings.density
        let origin = CGPoint(x: padded.width / 2, y: padded.height / 2)
        let corners = [CGPoint.zero, CGPoint(x: padded.width, y: 0), CGPoint(x: 0, y: padded.height), CGPoint(x: padded.width, y: padded.height)]
            .map { Iso.unproject(CGPoint(x: ($0.x - origin.x) / spacing, y: ($0.y - origin.y) / spacing)) }
        let minX = Int(floor(corners.map(\.x).min()!)), maxX = Int(ceil(corners.map(\.x).max()!))
        let minY = Int(floor(corners.map(\.y).min()!)), maxY = Int(ceil(corners.map(\.y).max()!))
        for x in minX...maxX {
            for y in minY...maxY {
                let p = Iso.project(Double(x) + 0.5, Double(y) + 0.5)
                let position = CGPoint(x: origin.x + p.x * spacing, y: origin.y + p.y * spacing)
                guard CGRect(origin: .zero, size: padded).insetBy(dx: -spacing, dy: -spacing).contains(position) else { continue }
                let group = CALayer(); group.bounds = CGRect(x: 0, y: 0, width: 256, height: 256); group.position = position
                group.setAffineTransform(CGAffineTransform(a: 0.8660254 * spacing / 256, b: 0.5 * spacing / 256,
                                                         c: -0.8660254 * spacing / 256, d: 0.5 * spacing / 256, tx: 0, ty: 0))
                func hand(length: CGFloat, width: CGFloat, tail: CGFloat = 0.035, color: NSColor = NSColor(white: 0.12, alpha: 1)) -> CALayer {
                    let layer = CAShapeLayer(); layer.bounds = CGRect(x: 0, y: 0, width: 256, height: 256)
                    layer.position = CGPoint(x: 128, y: 128); layer.contentsScale = 2
                    let path = CGMutablePath(); path.move(to: CGPoint(x: 128, y: 128 - tail * 256)); path.addLine(to: CGPoint(x: 128, y: 128 + length * 256))
                    layer.path = path; layer.strokeColor = color.cgColor; layer.lineWidth = width * 256; layer.lineCap = .round
                    group.addSublayer(layer); return layer
                }
                let hour = hand(length: 0.21, width: 0.028)
                let minute = hand(length: 0.295, width: 0.018)
                let second = hand(length: 0.32, width: 0.007, tail: 0.075, color: NSColor(srgbRed: 0.56, green: 0.24, blue: 0.14, alpha: 1))
                let hub = CAShapeLayer(); hub.path = CGPath(ellipseIn: CGRect(x: 122.1, y: 122.1, width: 11.8, height: 11.8), transform: nil)
                hub.fillColor = NSColor(white: 0.12, alpha: 1).cgColor; group.addSublayer(hub)
                stage.addSublayer(group)
                layerHands.append((Iso.cityIndex(x: x, y: y, count: ClockCity.all.count), hour, minute, second))
            }
        }
    }
    func draw(in c: CGContext, size: CGSize, time: Double, date: Date) {
        if faces.isEmpty { makeFaces() }
        motion.step(now: time, speed: settings.speed)
        let t = motion.elapsed
        c.setFillColor(settings.floor.color.cgColor); c.fill(CGRect(origin: .zero, size: size))
        // A square plane projected through an isometric basis; the clocks inhabit the floor.
        let spacing = max(115, min(240, (size.width - (paintingStaticFloor ? padding * 2 : 0)) / 6.0)) / settings.density
        let origin = CGPoint(x: size.width / 2 + (paintingStaticFloor ? 0 : sin(t / 130) * spacing * 0.35),
                             y: size.height / 2 + (paintingStaticFloor ? 0 : cos(t / 170) * spacing * 0.25))
        let corners = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            .map { Iso.unproject(CGPoint(x: ($0.x - origin.x) / spacing, y: ($0.y - origin.y) / spacing)) }
        let minX = Int(floor(corners.map(\.x).min()!)) - 1, maxX = Int(ceil(corners.map(\.x).max()!)) + 1
        let minY = Int(floor(corners.map(\.y).min()!)) - 1, maxY = Int(ceil(corners.map(\.y).max()!)) + 1
        let angles = calendars.map { HandAngles(date: date, calendar: $0, smooth: settings.smoothSeconds) }
        c.saveGState()
        c.translateBy(x: origin.x, y: origin.y)
        c.concatenate(CGAffineTransform(a: 0.8660254 * spacing, b: 0.5 * spacing, c: -0.8660254 * spacing, d: 0.5 * spacing, tx: 0, ty: 0))
        for x in minX...maxX {
            for y in minY...maxY {
                let rect = CGRect(x: Double(x), y: Double(y), width: 1, height: 1)
                let index = Iso.cityIndex(x: x, y: y, count: ClockCity.all.count)
                c.setFillColor(NSColor(white: (x + y) % 2 == 0 ? 1 : 0, alpha: 0.022).cgColor); c.fill(rect)
                c.setStrokeColor(NSColor.black.withAlphaComponent(0.22).cgColor); c.setLineWidth(0.006); c.stroke(rect.insetBy(dx: 0.008, dy: 0.008))
                c.setFillColor(NSColor.black.withAlphaComponent(0.23).cgColor)
                c.fillEllipse(in: rect.insetBy(dx: 0.094, dy: 0.094).offsetBy(dx: 0.025, dy: -0.045))
                c.draw(faces[index], in: rect.insetBy(dx: 0.08, dy: 0.08))
                if paintingStaticFloor { continue }
                let center = CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)
                let hands = angles[index]
                c.setLineCap(.round)
                for (angle, length, width) in [(hands.hour, 0.21, 0.028), (hands.minute, 0.295, 0.018)] {
                    line(c, from: CGPoint(x: center.x - sin(angle) * 0.035, y: center.y - cos(angle) * 0.035),
                         to: CGPoint(x: center.x + sin(angle) * length, y: center.y + cos(angle) * length), width: width, color: NSColor(white: 0.12, alpha: 1).cgColor)
                }
                line(c, from: CGPoint(x: center.x - sin(hands.second) * 0.075, y: center.y - cos(hands.second) * 0.075),
                     to: CGPoint(x: center.x + sin(hands.second) * 0.32, y: center.y + cos(hands.second) * 0.32), width: 0.007, color: NSColor(srgbRed: 0.56, green: 0.24, blue: 0.14, alpha: 1).cgColor)
                c.setFillColor(NSColor(white: 0.12, alpha: 1).cgColor)
                c.fillEllipse(in: CGRect(x: center.x - 0.023, y: center.y - 0.023, width: 0.046, height: 0.046))
            }
        }
        c.restoreGState()
        if paintingStaticFloor { return }
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [NSColor.black.withAlphaComponent(0.0).cgColor, NSColor.black.withAlphaComponent(0.40).cgColor] as CFArray, locations: [0, 1]) {
            c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width * 0.1, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }
}
