import AppKit

enum StrawberryArtwork {
    static let size=CGSize(width:4000,height:2200)
    static func backdrop(_ world:StrawberryWorld,_ settings:StrawberrySettings)->CGImage {
        let p=settings.palette.colors
        return WorldInk.image(size){c in
            WorldInk.rect(c,CGRect(origin:.zero,size:size),p.sky)
            let sky=CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),colors:[WorldInk.color(p.haze),WorldInk.color(p.sky)] as CFArray,locations:[0,1])!
            c.drawLinearGradient(sky,start:CGPoint(x:0,y:1220),end:CGPoint(x:0,y:2080),options:.drawsAfterEndLocation)
            for (i,s) in world.stars.enumerated(){WorldInk.oval(c,CGRect(x:s.x,y:s.y,width:i%9==0 ? 2:1,height:i%9==0 ? 2:1),p.light,0.2+Double(i%4)*0.11)}
            let moon=CGPoint(x:2510+sin(world.phase)*160,y:1770)
            WorldInk.glow(c,moon,235,p.light,0.055)
            let moonColor=WorldInk.blend(p.light,RGB(0.83,0.87,0.89),0.73)
            c.saveGState();c.addEllipse(in:CGRect(x:moon.x-35,y:moon.y-35,width:70,height:70));c.clip()
            WorldInk.oval(c,CGRect(x:moon.x-35,y:moon.y-35,width:70,height:70),moonColor,0.94)
            WorldInk.glow(c,CGPoint(x:moon.x-17,y:moon.y+18),64,p.light,0.11)
            var moonRandom=ArtRandom(state:world.seed &+ 702)
            for _ in 0..<24 {let radius=2+moonRandom.next()*9;WorldInk.oval(c,CGRect(x:moon.x-35+moonRandom.next()*70,y:moon.y-35+moonRandom.next()*70,width:radius,height:radius*0.75),p.haze,0.055)}
            c.restoreGState()
            // Wisps have varied profiles instead of uniformly glowing cloud bands.
            for i in 0..<7 {
                let x=900+Double(i)*360,y=1570+sin(Double(i)*2.3+world.phase)*80
                let path=CGMutablePath();path.move(to:CGPoint(x:x-200,y:y));path.addCurve(to:CGPoint(x:x+380,y:y+13),control1:CGPoint(x:x+10,y:y+30),control2:CGPoint(x:x+200,y:y-2));path.addCurve(to:CGPoint(x:x-200,y:y),control1:CGPoint(x:x+250,y:y+40),control2:CGPoint(x:x+50,y:y+23));c.addPath(path);c.setFillColor(WorldInk.color(p.haze,0.10));c.fillPath()
            }
            for (i,hill) in world.hills.enumerated(){
                let points=[CGPoint(x:0,y:1010)]+hill.map(\.point)+[CGPoint(x:4200,y:1010)]
                WorldInk.polygon(c,points,WorldInk.blend(p.sky,p.leaf,0.15+Double(i)*0.047))
                WorldInk.path(c,hill.map(\.point),p.leaf,0.7,0.12)
            }
            // Tiny aerial fruit clusters create depth without a wallpaper of identical dots.
            var r=ArtRandom(state:world.seed &+ 8)
            for _ in 0..<540 {
                let x=r.next()*4000,y=1400+r.next()*120,depth=(1520-y)/120
                WorldInk.oval(c,CGRect(x:x,y:y,width:1.2+depth*2,height:1.5+depth*2),p.fruit,0.13+depth*0.22)
            }
            for plant in world.plants where plant.scale>0.6 {WorldInk.softShadow(c,CGPoint(x:plant.position.x,y:plant.position.y+3),110*plant.scale,18*plant.scale,p.sky,0.34)}
            let soil=WorldInk.blend(p.sky,RGB(0.18,0.13,0.12),0.50)
            WorldInk.rect(c,CGRect(x:0,y:0,width:4000,height:1070),soil)
            // Long rock strata provide a continuous physical descent into the complex.
            for i in 0..<18 {
                let y=Double(i)*59
                WorldInk.polygon(c,[CGPoint(x:0,y:y),CGPoint(x:4000,y:y+sin(Double(i))*32),CGPoint(x:4000,y:y+37),CGPoint(x:0,y:y+53)],WorldInk.blend(soil,p.sky,Double(i%3)*0.15+0.1))
            }
            // Excavated chamber: curved earth ceiling, warmer agricultural infrastructure.
            let chamber=CGMutablePath();chamber.move(to:CGPoint(x:1080,y:150));chamber.addLine(to:CGPoint(x:1080,y:625));chamber.addCurve(to:CGPoint(x:2890,y:680),control1:CGPoint(x:1260,y:1060),control2:CGPoint(x:2600,y:1040));chamber.addLine(to:CGPoint(x:3020,y:160));chamber.closeSubpath()
            c.addPath(chamber);c.setFillColor(WorldInk.color(WorldInk.blend(p.sky,RGB(0,0,0),0.52)));c.fillPath()
            for i in 0..<5 {
                let x=1200+Double(i)*380
                WorldInk.path(c,[CGPoint(x:x,y:180),CGPoint(x:x-70,y:670),CGPoint(x:x+50,y:825),CGPoint(x:x+260,y:860)],WorldInk.blend(soil,p.light,0.15),10,0.7)
                WorldInk.path(c,[CGPoint(x:x+2,y:180),CGPoint(x:x-67,y:670),CGPoint(x:x+53,y:825)],p.light,1,0.12)
            }
            // Roots keep the same silhouette as they become organized cable trunks.
            c.saveGState();c.clip(to:CGRect(x:0,y:935,width:4000,height:135))
            for (i,plant) in world.plants.enumerated() where i%7==0 {
                let node=world.nodes[(i/9)%world.nodes.count]
                let path=CGMutablePath();path.move(to:plant.position.point);path.addCurve(to:node.point,control1:CGPoint(x:plant.position.x-40,y:990),control2:CGPoint(x:node.x+100,y:node.y+170));c.addPath(path);c.setStrokeColor(WorldInk.color(p.leaf,0.28));c.setLineWidth(1.2);c.strokePath()
                if settings.network != .hidden {c.addPath(path);c.setStrokeColor(WorldInk.color(p.signal,settings.network == .visible ? 0.18:0.065));c.setLineWidth(3);c.strokePath()}
            }
            c.restoreGState()
            if settings.network != .hidden {
                for e in world.edges {WorldInk.path(c,[world.nodes[e.a].point,world.nodes[e.b].point],p.signal,0.7,settings.network == .visible ? 0.17:0.055)}
            }
            // Raised floor and a narrow service stair leading to the surface hatch.
            WorldInk.polygon(c,[CGPoint(x:1150,y:220),CGPoint(x:2780,y:220),CGPoint(x:3000,y:360),CGPoint(x:1390,y:360)],WorldInk.blend(soil,p.light,0.11))
            WorldInk.polygon(c,[CGPoint(x:1150,y:220),CGPoint(x:2780,y:220),CGPoint(x:2780,y:196),CGPoint(x:1150,y:196)],p.sky)
            WorldInk.polygon(c,[CGPoint(x:2240,y:345),CGPoint(x:2570,y:990),CGPoint(x:2600,y:990),CGPoint(x:2270,y:345)],WorldInk.blend(soil,p.leaf,0.16))
            WorldInk.path(c,[CGPoint(x:2350,y:348),CGPoint(x:2670,y:990)],p.leaf,5,0.30)
            for i in 0..<19 {let x=2240+Double(i)*17,y=355+Double(i)*34
                WorldInk.polygon(c,[CGPoint(x:x,y:y),CGPoint(x:x+104,y:y),CGPoint(x:x+117,y:y+9),CGPoint(x:x+14,y:y+9)],WorldInk.blend(soil,p.light,0.18));WorldInk.path(c,[CGPoint(x:x+5,y:y+10),CGPoint(x:x+5,y:y+37)],p.leaf,2,0.5)
            }
            WorldInk.path(c,[CGPoint(x:2250,y:405),CGPoint(x:2560,y:1023)],p.leaf,3,0.5)
            WorldInk.softShadow(c,CGPoint(x:1680,y:303),650,88,p.sky,0.38)
            WorldInk.softShadow(c,CGPoint(x:2180,y:265),460,100,p.sky,0.34)
            for i in 0..<4 {rack(c,x:1420+Double(i)*126,y:325+Double(i%2)*15,p:p,index:i)}
            // A bench that treats an ordinary fruit basket like important research.
            WorldInk.polygon(c,[CGPoint(x:2010,y:390),CGPoint(x:2340,y:390),CGPoint(x:2410,y:445),CGPoint(x:2080,y:445)],WorldInk.blend(p.light,p.sky,0.55))
            WorldInk.path(c,[CGPoint(x:2010,y:390),CGPoint(x:2340,y:390)],p.light,1.4,0.30)
            WorldInk.polygon(c,[CGPoint(x:2010,y:390),CGPoint(x:2340,y:390),CGPoint(x:2340,y:383),CGPoint(x:2010,y:383)],WorldInk.blend(p.light,p.sky,0.74))
            for x in [2035.0,2312.0] {WorldInk.softShadow(c,CGPoint(x:x,y:252),34,11,p.sky,0.50)}
            WorldInk.path(c,[CGPoint(x:2035,y:390),CGPoint(x:2035,y:255)],p.leaf,8,0.6);WorldInk.path(c,[CGPoint(x:2312,y:390),CGPoint(x:2312,y:255)],p.leaf,8,0.6)
            for i in 0..<(settings.lore == .pureArt || world.seed%2==0 ? 2:3) {
                let x=2110+Double(i)*44
                WorldInk.softShadow(c,CGPoint(x:x+20,y:404),46,12,p.sky,0.55)
                WorldInk.polygon(c,[CGPoint(x:x+5,y:405),CGPoint(x:x+32,y:405),CGPoint(x:x+37,y:432),CGPoint(x:x,y:432)],WorldInk.blend(p.light,p.sky,0.72))
                WorldInk.polygon(c,[CGPoint(x:x+25,y:405),CGPoint(x:x+32,y:405),CGPoint(x:x+37,y:432),CGPoint(x:x+29,y:432)],p.sky,0.18)
                for j in 0..<3 {WorldInk.path(c,[CGPoint(x:x+5-Double(j),y:410+Double(j)*8),CGPoint(x:x+32+Double(j),y:410+Double(j)*8)],p.light,0.8,0.17)}
                WorldInk.oval(c,CGRect(x:x-1,y:428,width:39,height:9),WorldInk.blend(p.light,p.sky,0.48))
                WorldInk.oval(c,CGRect(x:x+2,y:430,width:33,height:5),p.sky,0.70)
                c.saveGState();c.translateBy(x:x+19,y:431);berry(c,p:p,scale:0.60);c.restoreGState()
            }
            // One warm cone and dark lamp hardware: light has a visible source.
            WorldInk.glow(c,CGPoint(x:2200,y:430),200,p.light,0.08)
            WorldInk.polygon(c,[CGPoint(x:2192,y:775),CGPoint(x:2207,y:775),CGPoint(x:2350,y:360),CGPoint(x:2050,y:360)],p.light,0.012)
            WorldInk.path(c,[CGPoint(x:2200,y:899),CGPoint(x:2200,y:780)],p.leaf,2,0.7)
            WorldInk.polygon(c,[CGPoint(x:2171,y:762),CGPoint(x:2229,y:762),CGPoint(x:2212,y:785),CGPoint(x:2188,y:785)],p.light,0.7)
            c.saveGState();c.translateBy(x:1810,y:610);c.scaleBy(x:0.8,y:0.8);c.translateBy(x:-1830,y:-600)
            WorldInk.polygon(c,[CGPoint(x:1830,y:600),CGPoint(x:2175,y:600),CGPoint(x:2200,y:623),CGPoint(x:2200,y:795),CGPoint(x:1855,y:795),CGPoint(x:1830,y:772)],WorldInk.blend(soil,p.leaf,0.16))
            WorldInk.polygon(c,[CGPoint(x:2175,y:600),CGPoint(x:2200,y:623),CGPoint(x:2200,y:795),CGPoint(x:2175,y:772)],p.sky)
            WorldInk.path(c,[CGPoint(x:1900,y:600),CGPoint(x:1900,y:330)],p.leaf,9,0.16)
            WorldInk.rect(c,CGRect(x:1845,y:610,width:318,height:158),WorldInk.blend(soil,p.leaf,0.09))
            WorldInk.path(c,[CGPoint(x:1845,y:610),CGPoint(x:1845,y:768),CGPoint(x:2163,y:768)],p.leaf,2,0.2)
            WorldInk.rect(c,CGRect(x:1870,y:648,width:274,height:76),p.sky)
            WorldInk.rect(c,CGRect(x:1880,y:658,width:254,height:56),p.signal,0.035)
            for i in 0..<3 {WorldInk.oval(c,CGRect(x:1884+Double(i)*23,y:624,width:9,height:9),p.light,0.22);WorldInk.path(c,[CGPoint(x:1970,y:628+Double(i)*5),CGPoint(x:2120,y:628+Double(i)*5)],p.leaf,0.6,0.16)}
            WorldInk.path(c,[CGPoint(x:1890,y:675),CGPoint(x:1910,y:675),CGPoint(x:1921,y:683),CGPoint(x:1940,y:683),CGPoint(x:1950,y:679),CGPoint(x:1973,y:679)],p.signal,0.8,0.13)
            for i in 0..<8 {WorldInk.rect(c,CGRect(x:2025+Double(i)*10,y:667,width:2,height:4+Double((i*7)%16)),p.signal,0.10)}
            c.restoreGState()
            WorldInk.path(c,[CGPoint(x:1866,y:610),CGPoint(x:1866,y:333)],p.leaf,7,0.15)
            WorldInk.path(c,[CGPoint(x:2330,y:493),CGPoint(x:2370,y:574)],p.light,0.9,0.19)
            // Ducts and a sealed door remain unbranded, with no fictional product claims.
            WorldInk.path(c,[CGPoint(x:1280,y:796),CGPoint(x:1680,y:796),CGPoint(x:1750,y:730)],p.leaf,21,0.14)
            for i in 0..<14 {WorldInk.path(c,[CGPoint(x:1300+Double(i)*26,y:786),CGPoint(x:1300+Double(i)*26,y:806)],p.light,1,0.18)}
            WorldInk.rect(c,CGRect(x:2720,y:390,width:115,height:221),WorldInk.blend(p.sky,p.leaf,0.13));WorldInk.path(c,[CGPoint(x:2720,y:390),CGPoint(x:2720,y:611),CGPoint(x:2835,y:611)],p.leaf,2,0.45)
            // Entrance anchored to the same stair, partially swallowed by vegetation.
            WorldInk.polygon(c,[CGPoint(x:2490,y:1073),CGPoint(x:2615,y:1073),CGPoint(x:2660,y:1104),CGPoint(x:2528,y:1104)],p.sky)
            WorldInk.polygon(c,[CGPoint(x:2528,y:1104),CGPoint(x:2660,y:1104),CGPoint(x:2632,y:1163),CGPoint(x:2506,y:1163)],WorldInk.blend(p.leaf,p.sky,0.52))
            WorldInk.path(c,[CGPoint(x:2506,y:1163),CGPoint(x:2632,y:1163)],p.light,1.2,0.3)
            WorldInk.glow(c,CGPoint(x:2570,y:1073),90,p.light,0.09)
        }
    }
    private static func rack(_ c:CGContext,x:Double,y:Double,p:StrawberryColors,index:Int){
        WorldInk.rect(c,CGRect(x:x,y:y,width:93,height:255),WorldInk.blend(p.sky,p.leaf,0.10))
        WorldInk.polygon(c,[CGPoint(x:x+93,y:y),CGPoint(x:x+113,y:y+19),CGPoint(x:x+113,y:y+274),CGPoint(x:x+93,y:y+255)],p.sky)
        WorldInk.polygon(c,[CGPoint(x:x,y:y+255),CGPoint(x:x+93,y:y+255),CGPoint(x:x+113,y:y+274),CGPoint(x:x+20,y:y+274)],WorldInk.blend(p.leaf,p.sky,0.7))
        for j in 0..<8 {
            let yy=y+18+Double(j)*29
            WorldInk.rect(c,CGRect(x:x+9,y:yy,width:76,height:17),p.sky)
            WorldInk.oval(c,CGRect(x:x+16,y:yy+6,width:3,height:3),j%3==index%3 ? p.fruit:p.light,0.55)
            WorldInk.path(c,[CGPoint(x:x+30,y:yy+8),CGPoint(x:x+73,y:yy+8)],p.leaf,0.6,0.35)
        }
        let wire=CGMutablePath();wire.move(to:CGPoint(x:x+44,y:y));wire.addCurve(to:CGPoint(x:x+225,y:y-83),control1:CGPoint(x:x-10,y:y-90),control2:CGPoint(x:x+190,y:y-55));c.addPath(wire);c.setStrokeColor(WorldInk.color(p.leaf,0.45));c.setLineWidth(2);c.strokePath()
    }
    static func plant(_ variant:Int,fruit:Int,p:StrawberryColors)->CGImage {
        WorldInk.image(CGSize(width:190,height:200),1.5){c in
            let center=CGPoint(x:95,y:8)
            for i in 0..<5 {
                let angle=Double(i)*1.10+Double(variant)*0.19,len=46+Double((i*17+variant*11)%52)
                let tip=CGPoint(x:95+cos(angle)*len*0.69,y:27+sin(angle)*len*0.22+len*0.50)
                let path=CGMutablePath();path.move(to:center);path.addQuadCurve(to:tip,control:CGPoint(x:94+(tip.x-95)*0.4,y:tip.y+22));c.addPath(path);c.setStrokeColor(WorldInk.color(p.leaf,0.7));c.setLineWidth(1.4);c.strokePath()
                c.saveGState();c.translateBy(x:tip.x,y:tip.y);c.rotate(by:angle*0.35-0.9)
                for l in -1...1 {c.saveGState();c.rotate(by:Double(l)*0.74);c.translateBy(x:0,y:l==0 ? 3:0);leaf(c,length:(l==0 ? 37:29)+Double((i+variant)%3)*3,width:l==0 ? 14:11,p:p,brightness:Double(i%3)*0.07);c.restoreGState()};c.restoreGState()
            }
            for i in 0..<fruit {
                let x=65+Double(i)*29+sin(Double(variant))*7,y=32+Double((i*13+variant*7)%31)
                let path=CGMutablePath();path.move(to:CGPoint(x:95,y:100));path.addQuadCurve(to:CGPoint(x:x,y:y+31),control:CGPoint(x:x-8,y:112));c.addPath(path);c.setStrokeColor(WorldInk.color(p.leaf));c.setLineWidth(1.1);c.strokePath()
                c.saveGState();c.translateBy(x:x,y:y);c.rotate(by:Double(i-1)*0.14);berry(c,p:p,scale:0.88+Double(i%2)*0.13,variation:Double((variant+i*3)%7)/7);c.restoreGState()
            }
            if variant%3 != 1 {for i in 0..<(2+variant%3) {
                c.saveGState();c.translateBy(x:89+Double((variant*7+i*11)%17),y:7+Double((variant+i*3)%5));c.scaleBy(x:1,y:0.38)
                c.rotate(by:Double(i)*1.87+Double(variant)*0.71)
                leaf(c,length:18+Double((variant+i*3)%5)*3,width:9,p:p,brightness:0.56);c.restoreGState()
            }}
            if variant%3==0 {c.saveGState();c.translateBy(x:122,y:119);for i in 0..<5 {c.saveGState();c.rotate(by:Double(i)*1.256);WorldInk.oval(c,CGRect(x:-3,y:0,width:6,height:12),p.light,0.58);c.restoreGState()};WorldInk.oval(c,CGRect(x:-3,y:-3,width:6,height:6),p.light);c.restoreGState()}
        }
    }
    private static func leaf(_ c:CGContext,length:Double,width:Double,p:StrawberryColors,brightness:Double){
        let path=CGMutablePath();path.move(to:.zero)
        for i in 1...16 {let t=Double(i)/16;path.addLine(to:CGPoint(x:sin(t * .pi)*width*(i%2==0 ? 0.97:1),y:t*length))}
        for i in (0...15).reversed(){let t=Double(i)/16;path.addLine(to:CGPoint(x:-sin(t * .pi)*width*(i%2==0 ? 0.97:1),y:t*length))};path.closeSubpath();c.addPath(path);c.setFillColor(WorldInk.color(WorldInk.blend(p.leaf,p.sky,0.25+brightness)));c.fillPath()
        let rim=CGMutablePath();rim.move(to:.zero);rim.addQuadCurve(to:CGPoint(x:0,y:length),control:CGPoint(x:-width*1.55,y:length*0.56));c.addPath(rim);c.setStrokeColor(WorldInk.color(p.light,0.11));c.setLineWidth(0.6);c.strokePath()
        c.saveGState();c.addPath(path);c.clip()
        WorldInk.polygon(c,[.zero,CGPoint(x:0,y:length),CGPoint(x:-width,y:length*0.6)],p.light,0.035+brightness*0.08);c.restoreGState()
        WorldInk.path(c,[.zero,CGPoint(x:0,y:length)],p.leaf,0.75,0.6)
        for i in 1...3 {let y=Double(i)*length/4,w=sin(y/length * .pi)*width*0.7;WorldInk.path(c,[CGPoint(x:-w,y:y+3),CGPoint(x:0,y:y),CGPoint(x:w,y:y+3)],p.leaf,0.45,0.30)}
    }
    static func berry(_ c:CGContext,p:StrawberryColors,scale:Double=1,variation:Double=0.3){
        c.saveGState();c.scaleBy(x:scale,y:scale);defer{c.restoreGState()}
        let path=CGMutablePath();path.move(to:CGPoint(x:0,y:0));path.addCurve(to:CGPoint(x:-17,y:31),control1:CGPoint(x:-8-variation*3,y:4),control2:CGPoint(x:-22-variation*5,y:26));path.addCurve(to:CGPoint(x:17,y:31),control1:CGPoint(x:-12,y:42),control2:CGPoint(x:12,y:42));path.addCurve(to:.zero,control1:CGPoint(x:23+variation*4,y:25),control2:CGPoint(x:9,y:5));path.closeSubpath()
        c.saveGState();c.addPath(path);c.clip()
        let gradient=CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),colors:[WorldInk.color(WorldInk.blend(p.fruit,p.light,0.08)),WorldInk.color(WorldInk.blend(p.fruit,p.sky,0.15)),WorldInk.color(WorldInk.blend(p.fruit,p.sky,0.73))] as CFArray,locations:[0,0.4,1])!
        c.drawLinearGradient(gradient,start:CGPoint(x:-18,y:39),end:CGPoint(x:20,y:2),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
        WorldInk.glow(c,CGPoint(x:-10,y:30),13,p.light,0.19)
        WorldInk.oval(c,CGRect(x:-12,y:29,width:2.3,height:4.4),p.light,0.15)
        for row in 0..<5 {for col in -2...2 {let y=7+Double(row)*5.8,x=Double(col)*6+Double(row%2)*2; if abs(x)<y*0.44+1 {WorldInk.oval(c,CGRect(x:x,y:y,width:1.0,height:2.1),p.light,0.13+Double((row*5+col+7)%5)*0.055)}}}
        c.restoreGState()
        for i in 0..<5 {let a=Double(i)*1.25;WorldInk.polygon(c,[CGPoint(x:0,y:35),CGPoint(x:cos(a)*17,y:36+sin(a)*7),CGPoint(x:cos(a+0.4)*7,y:36+sin(a+0.4)*4)],p.leaf)}
    }
}
