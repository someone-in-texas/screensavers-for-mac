import Foundation

struct ClockCity {
    let name: String
    let identifier: String
    let zone: TimeZone
    init(_ name: String, _ identifier: String) {
        self.name = name
        self.identifier = identifier
        zone = TimeZone(identifier: identifier) ?? TimeZone(secondsFromGMT: 0)!
    }
    static let all: [ClockCity] = [
        .init("Dallas", "America/Chicago"), .init("Tokyo", "Asia/Tokyo"),
        .init("London", "Europe/London"), .init("Paris", "Europe/Paris"),
        .init("Sydney", "Australia/Sydney"), .init("Singapore", "Asia/Singapore"),
        .init("New York", "America/New_York"), .init("Los Angeles", "America/Los_Angeles"),
        .init("Mexico City", "America/Mexico_City"), .init("São Paulo", "America/Sao_Paulo"),
        .init("Reykjavík", "Atlantic/Reykjavik"), .init("Nairobi", "Africa/Nairobi"),
        .init("Cairo", "Africa/Cairo"), .init("Dubai", "Asia/Dubai"),
        .init("Delhi", "Asia/Kolkata"), .init("Bangkok", "Asia/Bangkok"),
        .init("Seoul", "Asia/Seoul"), .init("Hong Kong", "Asia/Hong_Kong"),
        .init("Honolulu", "Pacific/Honolulu"), .init("Vancouver", "America/Vancouver")
    ]
}

struct HandAngles {
    let hour: Double
    let minute: Double
    let second: Double
    init(date: Date, calendar: Calendar, smooth: Bool) {
        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let second = Double(c.second ?? 0) + (smooth ? Double(c.nanosecond ?? 0) / 1e9 : 0)
        let minute = Double(c.minute ?? 0) + second / 60
        self.second = second / 60 * .pi * 2
        self.minute = minute / 60 * .pi * 2
        hour = (Double((c.hour ?? 0) % 12) + minute / 60) / 12 * .pi * 2
    }
}

enum Iso {
    static func project(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: (x - y) * 0.8660254, y: (x + y) * 0.5)
    }
    static func unproject(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.y + p.x / 1.7320508, y: p.y - p.x / 1.7320508)
    }
    static func cityIndex(x: Int, y: Int, count: Int) -> Int {
        let value = (x &* 7) &+ (y &* 11)
        return ((value % count) + count) % count
    }
}

/// Integrates monotonic deltas, so changing speed never jumps the camera.
struct MotionClock {
    private(set) var elapsed = 0.0
    private var previous: Double?
    mutating func step(now: Double, speed: Double) {
        if let previous { elapsed += max(0, min(now - previous, 0.25)) * speed }
        previous = now
    }
    mutating func pause() { previous = nil }
}
