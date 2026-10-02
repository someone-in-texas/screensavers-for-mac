import AppKit

/// Recolors the existing sRGB pixels without sharpening, neighborhood sampling or
/// per-tile normalization. Identical source pixels always receive identical colors,
/// including at tile boundaries; the source's antialiasing and resolution survive.
enum DarkMapTint {
    static func apply(to context: CGContext, background: RGB, ink: RGB, intensity: Double) {
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return }
        let strength = min(1, max(0, intensity))
        let original = 1 - strength
        for y in 0..<context.height {
            for x in 0..<context.width {
                let p = pixels + y * context.bytesPerRow + x * 4
                let r = Double(p[0]) / 255, g = Double(p[1]) / 255, b = Double(p[2]) / 255
                let shade = 1 - (0.2126 * r + 0.7152 * g + 0.0722 * b)
                p[0] = channel(background.r + shade * (ink.r - background.r), r, strength, original)
                p[1] = channel(background.g + shade * (ink.g - background.g), g, strength, original)
                p[2] = channel(background.b + shade * (ink.b - background.b), b, strength, original)
            }
        }
    }
    private static func channel(_ tinted: Double, _ source: Double, _ strength: Double, _ original: Double) -> UInt8 {
        UInt8(max(0, min(255, ((tinted * strength + source * original) * 255).rounded())))
    }
}
