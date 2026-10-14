import AppKit
import QuartzCore

/// Low-cost page washes and two depths of precipitation. Everything uses active
/// scene time and logical points; there are no timers, filters or frame textures.
final class BloomAtmosphere {
    let background = CALayer(), foreground = CALayer()
    private let veil = CALayer(), lightVeil = CALayer(), veilMask = CALayer(), lightMask = CALayer()
    private var fieldSeed: UInt64?
    private let page = CAGradientLayer(), halo = CAGradientLayer(), sunlight = CAGradientLayer()
    private let wind = CAShapeLayer(), rain = CAShapeLayer(), nearRain = CAShapeLayer()
    private let snow = CAShapeLayer(), nearSnow = CAShapeLayer()
    private let rainMask = CAGradientLayer(), snowMask = CAGradientLayer(), windMask = CAGradientLayer()
    private var size = CGSize.zero
    init() {
        for layer in [page,veil,lightVeil,halo,sunlight,wind] { background.addSublayer(layer) }
        for layer in [rain,snow,nearRain,nearSnow] { foreground.addSublayer(layer) }
        for mask in [rainMask,snowMask,windMask] {
            mask.type = .radial;mask.startPoint = CGPoint(x:0.50,y:0.46);mask.endPoint = CGPoint(x:0.92,y:0.94)
            mask.colors = [NSColor.black.cgColor,NSColor.black.withAlphaComponent(0.60).cgColor,NSColor.clear.cgColor]
            mask.locations = [0,0.45,1]
        }
        veil.mask = veilMask;lightVeil.mask = lightMask
        nearRain.mask = rainMask;nearSnow.mask = snowMask;wind.mask = windMask
        halo.type = .radial;halo.endPoint = CGPoint(x:0.98,y:0.98)
        page.startPoint = CGPoint(x:0.12,y:1);page.endPoint = CGPoint(x:0.88,y:0)
        sunlight.startPoint = CGPoint(x:0.08,y:0.98);sunlight.endPoint = CGPoint(x:0.76,y:0.20)
        for line in [wind,rain,nearRain,snow,nearSnow] { line.fillColor = nil;line.lineCap = .round }
    }
    func update(size: CGSize, seconds: Double, season: BloomCalendar, settings: BloomSettings, paper: NSColor, ink: NSColor, seed: UInt64) {
        if self.size != size {
            self.size = size
            for layer in [background,foreground,page,halo,sunlight,wind,rain,nearRain,snow,nearSnow,rainMask,snowMask,windMask] { layer.frame = CGRect(origin:.zero,size:size) }
        }
        if fieldSeed != seed {
            let mask = BloomWeatherField.mask(seed:seed)
            veilMask.contents = mask;lightMask.contents = BloomWeatherField.mask(seed:seed &+ 12563);fieldSeed = seed
        }
        let fieldSize = CGSize(width:size.width*1.60,height:size.height*1.60)
        for layer in [veil,lightVeil,veilMask,lightMask] { layer.bounds = CGRect(origin:.zero,size:fieldSize) }
        veilMask.position = CGPoint(x:fieldSize.width/2,y:fieldSize.height/2);lightMask.position = veilMask.position
        veil.position = CGPoint(x:size.width*(0.50+0.12*sin(seconds*0.015)),y:size.height*(0.50+0.09*cos(seconds*0.011)))
        lightVeil.position = CGPoint(x:size.width*(0.50+0.08*cos(seconds*0.019)),y:size.height*(0.50+0.10*sin(seconds*0.013)))
        lightVeil.setAffineTransform(.identity)
        let summer = max(0,1-abs(season.phase-0.38)*5)
        let winter = season.winter
        let yearEnd = min(1,max(0,(season.phase-0.94)/0.06))
        let autumn = season.autumn*(1-winter)*(1-yearEnd*yearEnd*(3-2*yearEnd))
        let sun = summer*(1-season.rain*0.85)
        let cool = NSColor(srgbRed:0.36,green:0.49,blue:0.57,alpha:1)
        let warm = NSColor(srgbRed:0.88,green:0.65,blue:0.31,alpha:1)
        let frost = NSColor(srgbRed:0.63,green:0.72,blue:0.78,alpha:1)
        let spring = NSColor(srgbRed:0.48,green:0.62,blue:0.51,alpha:1)
        let seasonal = spring.blended(withFraction:min(1,sun+autumn*0.78),of:warm)!.blended(withFraction:winter,of:frost)!
        let tint = seasonal.blended(withFraction:season.rain*0.82,of:cool)!
        // Negative space remains paper, with a perceptible but quiet weather cast.
        veil.backgroundColor = tint.withAlphaComponent(0.055+season.rain*0.20+winter*0.17+sun*0.06).cgColor
        lightVeil.backgroundColor = (winter>0.2 ? frost:paper).withAlphaComponent(0.04+season.rain*0.08+winter*0.10+sun*0.12).cgColor
        let pageAlpha = 0.027+sun*0.023+season.rain*0.070+winter*0.08
        page.colors = [tint.withAlphaComponent(pageAlpha).cgColor,tint.withAlphaComponent(pageAlpha*0.32).cgColor]
        let gust = sin(seconds*0.11)+0.35*sin(seconds*0.27)
        halo.startPoint = CGPoint(x:0.49+gust*0.035*season.wind,y:0.48+sin(seconds*0.043)*0.025)
        halo.colors = [tint.withAlphaComponent(0.12+sun*0.08+season.rain*0.17+winter*0.23).cgColor,tint.withAlphaComponent(0.07).cgColor,tint.withAlphaComponent(0).cgColor]
        halo.locations = [0,0.44,1]
        sunlight.colors = [warm.withAlphaComponent(sun*0.065).cgColor,paper.withAlphaComponent(sun*0.025).cgColor,NSColor.clear.cgColor]
        sunlight.locations = [0,0.48,1]
        let air = CGMutablePath()
        var breeze = ArtRandom(state:seed &+ 127)
        for i in 0..<4 {
            let phase = breeze.next()*6.28
            let x = size.width*(0.02+breeze.next()*0.52)+gust*size.width*0.018
            let y = size.height*(0.23+breeze.next()*0.57)+sin(seconds*0.09+phase)*size.height*0.028
            let length = size.width*(0.18+breeze.next()*0.25)
            let rise = size.height*(0.015+breeze.next()*0.07)*(i%2 == 0 ? 1:-1)
            air.move(to:CGPoint(x:x,y:y))
            air.addCurve(to:CGPoint(x:x+length,y:y+rise),control1:CGPoint(x:x+length*0.35,y:y+rise*0.1),control2:CGPoint(x:x+length*0.75,y:y+rise*1.4))
        }
        wind.path = air;wind.lineWidth = 0.75
        wind.strokeColor = ink.withAlphaComponent(season.wind*(0.035+0.012*(gust+1)/2)).cgColor
        let rainPath = CGMutablePath(), snowPath = CGMutablePath()
        var random = ArtRandom(state:seed &+ 800)
        func wrap(_ value: Double) -> Double { value-floor(value) }
        // Use separate populations so rain-to-snow is a continuous crossfade.
        for _ in 0..<110 {
            let origin = CGPoint(x:random.next(),y:random.next())
            let windScale = settings.weather == .calm ? 0.2:settings.weather == .dramatic ? 1.0:0.65
            let drop = BloomWeatherField.rain(seconds:seconds,size:size,origin:origin,speed:0.15+random.next()*0.07,wind:windScale,length:5+random.next()*7)
            rainPath.move(to:drop.tail);rainPath.addLine(to:drop.head)
        }
        for _ in 0..<64 {
            let phase = random.next()*6.28
            let x = wrap(random.next()+seconds*0.007+sin(seconds*0.24+phase)*0.009*season.wind)
            let y = wrap(random.next()-seconds*(0.010+random.next()*0.010))
            let r = 0.65+random.next()*1.2
            let at = CGPoint(x:x*(size.width+12)-6,y:y*(size.height+12)-6)
            snowPath.addEllipse(in:CGRect(x:at.x,y:at.y,width:r,height:r*0.82))
        }
        rain.path = rainPath;nearRain.path = rainPath
        rain.strokeColor = cool.blended(withFraction:0.24,of:ink)!.withAlphaComponent(season.rain*0.23).cgColor
        nearRain.strokeColor = ink.withAlphaComponent(season.rain*0.40).cgColor
        rain.lineWidth = 0.55;nearRain.lineWidth = 0.65
        // Muted blue-gray distant flakes remain legible on ivory; near flakes are
        // paper-white against the cooler wash, without confetti-sized circles.
        snow.path = snowPath;nearSnow.path = snowPath
        snow.fillColor = cool.withAlphaComponent(winter*0.34*(settings.weather == .calm ? 0.35:1)).cgColor;snow.strokeColor = nil
        let snowfall = settings.weather == .calm ? 0.35:settings.weather == .dramatic ? 1:0.72
        nearSnow.fillColor = NSColor(srgbRed:0.99,green:0.99,blue:0.96,alpha:winter*0.82*snowfall).cgColor;nearSnow.strokeColor = nil
    }
}
