import AppKit

enum ResearchArtwork {
    static let size=CGSize(width:4000,height:1800)
    static func project(_ x:Double,_ y:Double,_ z:Double)->CGPoint {CGPoint(x:2100+x*0.88-z*0.65,y:540+x*0.23+z*0.36+y)}
    static func box(_ c:CGContext,x:Double,y:Double,z:Double,w:Double,h:Double,d:Double,color:RGB){
        WorldInk.polygon(c,[project(x,y,z),project(x+w,y,z),project(x+w,y+h,z),project(x,y+h,z)],WorldInk.blend(color,RGB(0,0,0),0.22))
        WorldInk.polygon(c,[project(x+w,y,z),project(x+w,y,z+d),project(x+w,y+h,z+d),project(x+w,y+h,z)],WorldInk.blend(color,RGB(0,0,0),0.48))
        WorldInk.polygon(c,[project(x,y+h,z),project(x+w,y+h,z),project(x+w,y+h,z+d),project(x,y+h,z+d)],color)
    }
    static func backdrop(_ world:ResearchWorld,_ settings:ResearchSettings)->CGImage {
        let p=settings.palette.colors
        return WorldInk.image(size){c in
            WorldInk.rect(c,CGRect(origin:.zero,size:size),p.dark)
            // Geological planes, broad tonal shifts, no uniform sci-fi glowing outlines.
            WorldInk.glow(c,CGPoint(x:2350,y:1020),700,p.stone,0.33)
            for (i,rock) in world.rocks.enumerated(){WorldInk.polygon(c,rock.map(\.point),WorldInk.blend(p.dark,p.stone,0.10+Double(i%5)*0.038))}
            // Distant opening: outside is luminous, inside remains measured.
            let opening=CGMutablePath();opening.move(to:CGPoint(x:2620,y:990));opening.addLine(to:CGPoint(x:2670,y:1330));opening.addCurve(to:CGPoint(x:2780,y:1340),control1:CGPoint(x:2700,y:1370),control2:CGPoint(x:2760,y:1380));opening.addLine(to:CGPoint(x:2820,y:1000));opening.closeSubpath()
            c.addPath(opening);c.setFillColor(WorldInk.color(p.screen,0.16));c.fillPath()
            WorldInk.polygon(c,[CGPoint(x:2680,y:1330),CGPoint(x:2770,y:1335),CGPoint(x:2320,y:410),CGPoint(x:1990,y:450)],p.screen,0.025)
            WorldInk.path(c,[CGPoint(x:2670,y:1330),CGPoint(x:2620,y:990)],p.screen,1,0.15)
            // Coherent rooms connected by visible raised walkways, far behind the hero desk.
            for edge in world.connections {
                let a=world.rooms[edge.a].center,b=world.rooms[edge.b].center
                WorldInk.path(c,[a.point,b.point],WorldInk.blend(p.dark,p.stone,0.5),19)
                WorldInk.path(c,[CGPoint(x:a.x,y:a.y+17),CGPoint(x:b.x,y:b.y+17)],p.stone,1.4,0.45)
            }
            for (i,room) in world.rooms.enumerated(){
                let x=room.center.x,y=room.center.y,w=room.width,h=room.height
                let arch=CGMutablePath();arch.move(to:CGPoint(x:x-w/2,y:y));arch.addLine(to:CGPoint(x:x-w/2,y:y+h*0.65));arch.addCurve(to:CGPoint(x:x+w/2,y:y+h*0.65),control1:CGPoint(x:x-w*0.4,y:y+h*1.15),control2:CGPoint(x:x+w*0.4,y:y+h*1.2));arch.addLine(to:CGPoint(x:x+w/2,y:y));arch.closeSubpath()
                c.addPath(arch);c.setFillColor(WorldInk.color(WorldInk.blend(p.dark,p.stone,0.07)));c.fillPath()
                c.addPath(arch);c.setStrokeColor(WorldInk.color(p.stone,0.23));c.setLineWidth(24);c.strokePath()
                c.saveGState();c.addPath(arch);c.clip();WorldInk.rect(c,CGRect(x:x-w/2,y:y,width:24,height:h),p.paper,0.07);WorldInk.rect(c,CGRect(x:x-w/2+24,y:y+16,width:w-32,height:20),p.stone,0.20);c.restoreGState()
                if i%2==0 {
                    c.saveGState();c.addPath(arch);c.clip()
                    WorldInk.polygon(c,[CGPoint(x:x-55,y:y+24),CGPoint(x:x+92,y:y+24),CGPoint(x:x+92,y:y+h*0.67),CGPoint(x:x-55,y:y+h*0.71)],p.dark)
                    WorldInk.path(c,[CGPoint(x:x-55,y:y+24),CGPoint(x:x-55,y:y+h*0.71),CGPoint(x:x+92,y:y+h*0.67)],p.stone,4,0.30)
                    WorldInk.oval(c,CGRect(x:x+66,y:y+h*0.53,width:3,height:3),p.lamp,0.25);c.restoreGState()
                }
                WorldInk.rect(c,CGRect(x:x-w/2,y:y,width:w,height:14),p.stone,0.5)
                WorldInk.path(c,[CGPoint(x:x-w/2,y:y+1),CGPoint(x:x+w/2,y:y+1)],p.paper,0.8,0.12)
                if i<settings.activity.count {
                    for j in 0..<3 {WorldInk.rect(c,CGRect(x:x-90+Double(j)*58,y:y+35,width:45,height:96),p.stone,0.22);for k in 0..<5 {WorldInk.rect(c,CGRect(x:x-85+Double(j)*58,y:y+45+Double(k)*14,width:32,height:2),p.screen,0.12)}}
                    WorldInk.glow(c,CGPoint(x:x,y:y+h*0.7),110,p.lamp,0.08)
                    WorldInk.oval(c,CGRect(x:x-2,y:y+h*0.7,width:4,height:3),p.lamp,0.7)
                }
                if world.environment == .deepLab {
                    WorldInk.rect(c,CGRect(x:x-110,y:y+40,width:220,height:88),p.stone,0.18)
                    for j in 0..<4 {WorldInk.oval(c,CGRect(x:x-83+Double(j)*48,y:y+78,width:21,height:21),p.screen,0.10);WorldInk.path(c,[CGPoint(x:x-72+Double(j)*48,y:y+88),CGPoint(x:x-67+Double(j)*48,y:y+94)],p.paper,0.8,0.3)}
                }
                if world.environment == .archive {for j in 0..<4 {let yy=y+30+Double(j)*38;WorldInk.rect(c,CGRect(x:x-w*0.32,y:yy,width:w*0.64,height:4),p.stone);for k in 0..<13 {WorldInk.rect(c,CGRect(x:x-w*0.30+Double(k)*19,y:yy+4,width:8+Double(k%3),height:18+Double((j+k)%3)*4),WorldInk.blend(p.paper,p.dark,0.6+Double(k%3)*0.05))}}}
            }
            // Monumental foreground buttresses frame the institution without blocking its center.
            WorldInk.polygon(c,[CGPoint(x:1110,y:270),CGPoint(x:1260,y:285),CGPoint(x:1440,y:1420),CGPoint(x:1260,y:1630)],WorldInk.blend(p.dark,p.stone,0.27))
            WorldInk.polygon(c,[CGPoint(x:1260,y:285),CGPoint(x:1290,y:270),CGPoint(x:1470,y:1430),CGPoint(x:1440,y:1420)],p.dark)
            WorldInk.path(c,[CGPoint(x:1272,y:400),CGPoint(x:1410,y:1320)],p.paper,0.8,0.1)
            WorldInk.polygon(c,[CGPoint(x:2980,y:220),CGPoint(x:3100,y:200),CGPoint(x:3230,y:1660),CGPoint(x:3020,y:1480)],WorldInk.blend(p.dark,p.stone,0.24))
            // Continuous stone floor joins the chambers, falling into shadow at the edges.
            WorldInk.polygon(c,[CGPoint(x:680,y:0),CGPoint(x:3510,y:0),CGPoint(x:3440,y:850),CGPoint(x:2860,y:945),CGPoint(x:2450,y:930),CGPoint(x:1480,y:760),CGPoint(x:730,y:865)],WorldInk.blend(p.stone,p.dark,0.40))
            WorldInk.polygon(c,[project(-700,-8,-220),project(700,-8,-220),project(700,-8,560),project(-700,-8,560)],WorldInk.blend(p.stone,p.dark,0.32))
            WorldInk.path(c,[CGPoint(x:760,y:680),CGPoint(x:1290,y:568),project(-650,0,170)],p.paper,0.7,0.08)
            WorldInk.path(c,[project(660,0,400),CGPoint(x:2980,y:684),CGPoint(x:3380,y:750)],p.paper,0.7,0.08)
            for i in 0..<8 {WorldInk.path(c,[project(-670+Double(i)*190,0,-210),project(-670+Double(i)*190,0,550)],p.paper,0.6,0.06)}
            for i in 0..<9 {let y = -46-Double(i)*17;box(c,x:520+Double(i)*19,y:y,z:-185,w:145,h:7,d:84,color:WorldInk.blend(p.stone,p.dark,0.15))}
            // An integrated maze table; warm light falls on its physical raised walls.
            for x in [-100.0,232.0] {for z in [125.0,323.0] {let foot=project(x+7,0,z+7);WorldInk.softShadow(c,foot,31,10,p.dark,0.56);WorldInk.oval(c,CGRect(x:foot.x-7,y:foot.y-2,width:14,height:4),p.dark,0.35)}}
            box(c,x:-100,y:0,z:125,w:14,h:132,d:14,color:p.stone);box(c,x:232,y:0,z:125,w:14,h:132,d:14,color:p.stone)
            box(c,x:-100,y:0,z:323,w:14,h:132,d:14,color:p.stone);box(c,x:232,y:0,z:323,w:14,h:132,d:14,color:p.stone)
            box(c,x:-125,y:128,z:110,w:400,h:11,d:252,color:WorldInk.blend(p.stone,p.paper,0.28))
            let cell=21.0
            if settings.mazes != .rare || world.seed%3==0 {
                WorldInk.polygon(c,[project(-80,140,143),project(193,140,143),project(193,140,332),project(-80,140,332)],WorldInk.blend(p.dark,p.screen,0.13))
                for row in 0..<world.maze.rows {for col in 0..<world.maze.columns {
                    let node=row*world.maze.columns+col,x = -80+Double(col)*cell,z=143+Double(row)*cell
                    if row==0 || !world.maze.open(node,node-world.maze.columns){box(c,x:x,y:141,z:z,w:cell+1,h:6,d:1.8,color:WorldInk.blend(p.screen,p.stone,0.30))}
                    if col==0 || !world.maze.open(node,node-1){box(c,x:x,y:141,z:z,w:1.8,h:6,d:cell+1,color:WorldInk.blend(p.screen,p.stone,0.35))}
                }}
                box(c,x:-80,y:141,z:332,w:275,h:6,d:1.8,color:p.screen);box(c,x:193,y:141,z:143,w:1.8,h:6,d:190,color:p.screen)
            } else {paper(c,x:-70,y:141,z:170,p:p)}
            // Separate work desk, a CRT, paper, and a visible task lamp.
            box(c,x:-565,y:108,z:170,w:330,h:9,d:148,color:WorldInk.blend(p.paper,p.stone,0.68))
            for x in [-545.0,-258.0] {for z in [186.0,292.0] {WorldInk.softShadow(c,project(x+6,0,z+6),29,9,p.dark,0.52)};box(c,x:x,y:0,z:186,w:12,h:110,d:12,color:p.stone);box(c,x:x,y:0,z:292,w:12,h:110,d:12,color:p.stone)}
            box(c,x:-492,y:120,z:237,w:97,h:63,d:48,color:WorldInk.blend(p.stone,p.paper,0.14))
            WorldInk.glow(c,project(-440,145,229),73,p.screen,0.055)
            WorldInk.polygon(c,[project(-483,131,236),project(-406,131,236),project(-406,174,236),project(-483,174,236)],p.screen,0.24)
            WorldInk.path(c,[project(-483,174,236),project(-406,174,236)],p.paper,0.6,0.2)
            for i in 0..<5 {WorldInk.path(c,[project(-476,140+Double(i)*6,235),project(-436+Double(i%3)*9,140+Double(i)*6,235)],p.screen,0.8,0.36)}
            box(c,x:-478,y:118,z:206,w:86,h:3,d:25,color:p.stone)
            paper(c,x:-371,y:119,z:205,p:p)
            let lamp=project(-286,229,273),pool=project(-357,120,238)
            WorldInk.glow(c,pool,160,p.lamp,0.14)
            WorldInk.path(c,[project(-280,118,288),project(-280,180,288),lamp],p.paper,3,0.45)
            WorldInk.polygon(c,[CGPoint(x:lamp.x-19,y:lamp.y-6),CGPoint(x:lamp.x+22,y:lamp.y-6),CGPoint(x:lamp.x+6,y:lamp.y+10),CGPoint(x:lamp.x-5,y:lamp.y+10)],p.lamp,0.83)
            WorldInk.polygon(c,[CGPoint(x:lamp.x-18,y:lamp.y-8),CGPoint(x:lamp.x+20,y:lamp.y-8),CGPoint(x:pool.x+67,y:pool.y-12),CGPoint(x:pool.x-72,y:pool.y-22)],p.lamp,0.018)
            let seatPool=project(-380,0,62)
            WorldInk.glow(c,seatPool,145,p.lamp,0.105)
            WorldInk.softShadow(c,CGPoint(x:seatPool.x+18,y:seatPool.y-8),190,61,p.dark,0.47)
            chair(c,x:-380,z:62,p:p,scale:1.10)
            // Distinct side chambers are reached by the same continuous camera path.
            sideChambers(c,world:world,settings:settings)
            // Wall display and an analog timer: status stays in one believable surface.
            WorldInk.rect(c,CGRect(x:2204,y:885,width:322,height:145),WorldInk.blend(p.dark,p.stone,0.35))
            WorldInk.rect(c,CGRect(x:2217,y:898,width:296,height:119),p.dark)
            WorldInk.path(c,[CGPoint(x:2226,y:944),CGPoint(x:2270,y:946),CGPoint(x:2320,y:948),CGPoint(x:2380,y:950),CGPoint(x:2490,y:951)],p.screen,1,0.2)
            WorldInk.label(c,"SPATIAL STUDY",CGPoint(x:2229,y:990),11,p.paper,0.5)
            if settings.mazes == .frequent {for i in 0..<5 {WorldInk.path(c,[CGPoint(x:2230+Double(i)*12,y:915),CGPoint(x:2230+Double(i)*12,y:975),CGPoint(x:2280+Double(i)*12,y:975)],p.screen,0.8,0.18)}}
            WorldInk.oval(c,CGRect(x:1942,y:941,width:60,height:60),p.stone)
            WorldInk.oval(c,CGRect(x:1946,y:945,width:52,height:52),p.paper,0.64)
            for i in 0..<12 {let a=Double(i)*Double.pi/6;WorldInk.path(c,[CGPoint(x:1972+sin(a)*21,y:971+cos(a)*21),CGPoint(x:1972+sin(a)*24,y:971+cos(a)*24)],p.dark,1)}
            // Nearby concrete seams and small chips; distant rock stays broad and quiet.
            var material=ArtRandom(state:world.seed &+ 940)
            for _ in 0..<80 {let x=1320+material.next()*1550,y=320+material.next()*660;WorldInk.path(c,[CGPoint(x:x,y:y),CGPoint(x:x+3+material.next()*8,y:y+material.next()*2)],p.paper,0.5,0.016+material.next()*0.025)}
            // Cable runs curve, trail off, and remain grounded in the architecture.
            for i in 0..<4 {
                let path=CGMutablePath();path.move(to:project(-410+Double(i)*12,0,212));path.addCurve(to:project(590,0,490+Double(i)*8),control1:project(-250,0,-150-Double(i)*25),control2:project(560,0,120));c.addPath(path);c.setLineWidth(1.2);c.setStrokeColor(WorldInk.color(p.paper,0.12));c.strokePath()
            }
        }
    }
    private static func sideChambers(_ c:CGContext,world:ResearchWorld,settings:ResearchSettings){
        let p=settings.palette.colors
        // Chair alcove: a floor, back wall, side reveal and heavy foreground jamb.
        c.saveGState();if world.seed%2==1 {c.translateBy(x:1900,y:0)}
        WorldInk.polygon(c,[CGPoint(x:960,y:690),CGPoint(x:1280,y:730),CGPoint(x:1280,y:1200),CGPoint(x:960,y:1160)],WorldInk.blend(p.dark,p.stone,0.12))
        WorldInk.polygon(c,[CGPoint(x:875,y:630),CGPoint(x:960,y:690),CGPoint(x:960,y:1160),CGPoint(x:890,y:1120)],WorldInk.blend(p.dark,p.stone,0.20))
        WorldInk.polygon(c,[CGPoint(x:875,y:630),CGPoint(x:1210,y:670),CGPoint(x:1280,y:730),CGPoint(x:960,y:690)],WorldInk.blend(p.stone,p.dark,0.40))
        WorldInk.polygon(c,[CGPoint(x:890,y:1120),CGPoint(x:960,y:1160),CGPoint(x:1280,y:1200),CGPoint(x:1210,y:1160)],WorldInk.blend(p.stone,p.dark,0.60))
        WorldInk.path(c,[CGPoint(x:960,y:690),CGPoint(x:1280,y:730)],p.paper,0.8,0.13)
        WorldInk.glow(c,CGPoint(x:1080,y:683),165,p.lamp,0.18)
        WorldInk.path(c,[CGPoint(x:1110,y:1240),CGPoint(x:1110,y:1020)],p.stone,1.2)
        WorldInk.oval(c,CGRect(x:1090,y:1014,width:40,height:7),p.lamp,0.7)
        WorldInk.polygon(c,[CGPoint(x:1104,y:1014),CGPoint(x:1116,y:1014),CGPoint(x:1210,y:680),CGPoint(x:981,y:680)],p.lamp,0.008)
        if settings.lore != .pureArt {
            let origin=project(0,0,0);c.saveGState();c.translateBy(x:1080-origin.x,y:683-origin.y);chair(c,x:0,z:0,p:p,scale:1.25);c.restoreGState()
        } else {
            WorldInk.rect(c,CGRect(x:1038,y:690,width:104,height:55),p.stone,0.6)
            for i in 0..<4 {WorldInk.rect(c,CGRect(x:1050,y:742+Double(i)*5,width:68+Double(i%2)*8,height:4),p.paper,0.4)}
        }
        WorldInk.polygon(c,[CGPoint(x:856,y:621),CGPoint(x:878,y:630),CGPoint(x:895,y:1140),CGPoint(x:870,y:1130)],WorldInk.blend(p.dark,p.stone,0.34))
        WorldInk.path(c,[CGPoint(x:878,y:660),CGPoint(x:892,y:1110)],p.paper,0.65,0.07)
        c.restoreGState()
        c.saveGState();if world.seed%2==1 {c.translateBy(x:-1900,y:0)}
        // An observatory of shelving and a wall-mounted original maze, not a copy of the main desk.
        WorldInk.polygon(c,[CGPoint(x:2910,y:675),CGPoint(x:3480,y:745),CGPoint(x:3480,y:1260),CGPoint(x:2910,y:1190)],WorldInk.blend(p.dark,p.stone,0.14))
        WorldInk.polygon(c,[CGPoint(x:2840,y:610),CGPoint(x:2910,y:675),CGPoint(x:2910,y:1190),CGPoint(x:2840,y:1160)],WorldInk.blend(p.dark,p.stone,0.24))
        WorldInk.polygon(c,[CGPoint(x:2840,y:610),CGPoint(x:3420,y:680),CGPoint(x:3480,y:745),CGPoint(x:2910,y:675)],WorldInk.blend(p.stone,p.dark,0.38))
        var books=ArtRandom(state:world.seed &+ 870)
        for j in 0..<4 {
            let y=725+Double(j)*98
            WorldInk.polygon(c,[CGPoint(x:2900,y:y),CGPoint(x:3370,y:y+36),CGPoint(x:3383,y:y+48),CGPoint(x:2913,y:y+12)],WorldInk.blend(p.stone,p.paper,0.07))
            WorldInk.path(c,[CGPoint(x:2900,y:y-4),CGPoint(x:3370,y:y+32)],p.dark,5,0.50)
            var x=2910.0
            while x<3350 {
                let w=6+books.next()*12,h=22+books.next()*36,yy=y+(x-2900)*0.077+4,lean=(books.next()-0.5)*7
                let color=WorldInk.blend(p.paper,p.dark,0.59+books.next()*0.17)
                WorldInk.polygon(c,[CGPoint(x:x,y:yy),CGPoint(x:x+w,y:yy+w*0.077),CGPoint(x:x+w+lean,y:yy+h),CGPoint(x:x+lean,y:yy+h)],color)
                WorldInk.path(c,[CGPoint(x:x+1+lean,y:yy+h),CGPoint(x:x+w+lean,y:yy+h)],p.paper,0.6,0.18)
                x+=w+2+(books.next()<0.17 ? books.next()*22:0)
            }
        }
        // Steel mounting rails make the board an intentional instrument in front of the archive.
        for y in [788.0,993.0] {WorldInk.path(c,[CGPoint(x:2948,y:y),CGPoint(x:3285,y:y+26)],p.stone,5,0.7)}
        for x in [2956.0,3269.0] {let offset=(x-2956)*0.077;WorldInk.path(c,[CGPoint(x:x,y:777+offset),CGPoint(x:x,y:1012+offset)],p.stone,4,0.7)}
        // The maze is engraved into a sloping wall panel in the shelf's plane.
        c.saveGState();c.concatenate(CGAffineTransform(a:1,b:0.077,c:0,d:1,tx:2970,ty:792))
        WorldInk.rect(c,CGRect(x:-6,y:-7,width:287,height:206),p.stone,0.42)
        WorldInk.rect(c,CGRect(x:0,y:0,width:277,height:194),p.dark)
        for row in 0..<world.maze.rows {for col in 0..<world.maze.columns {
            let node=row*world.maze.columns+col,x=9+Double(col)*20,y=11+Double(row)*19
            if row==0 || !world.maze.open(node,node-world.maze.columns){WorldInk.path(c,[CGPoint(x:x,y:y),CGPoint(x:x+20,y:y)],p.screen,1.2,0.36)}
            if col==0 || !world.maze.open(node,node-1){WorldInk.path(c,[CGPoint(x:x,y:y),CGPoint(x:x,y:y+19)],p.screen,1.2,0.36)}
        }}
        c.restoreGState()
        WorldInk.path(c,[CGPoint(x:3110,y:1230),CGPoint(x:3110,y:1060)],p.stone,1.3)
        WorldInk.oval(c,CGRect(x:3095,y:1055,width:30,height:5),p.lamp,0.55)
        WorldInk.glow(c,CGPoint(x:3110,y:1000),200,p.lamp,0.09)
        WorldInk.polygon(c,[CGPoint(x:2920,y:610),CGPoint(x:3270,y:610),CGPoint(x:3360,y:675),CGPoint(x:3020,y:675)],p.stone,0.40)
        WorldInk.path(c,[CGPoint(x:2840,y:640),CGPoint(x:2840,y:1150)],p.stone,13,0.6)
        c.restoreGState()
    }
    private static func paper(_ c:CGContext,x:Double,y:Double,z:Double,p:ResearchColors){
        WorldInk.polygon(c,[project(x,y,z),project(x+75,y,z),project(x+75,y,z+88),project(x,y,z+88)],p.paper,0.84)
        for i in 1..<7 {WorldInk.path(c,[project(x+7,y+0.5,z+Double(i)*11),project(x+68,y+0.5,z+Double(i)*11)],p.stone,0.6,0.4)}
        WorldInk.path(c,[project(x+13,y+1,z+13),project(x+23,y+1,z+43),project(x+40,y+1,z+38),project(x+54,y+1,z+71)],p.stone,1,0.6)
    }
    static func chair(_ c:CGContext,x:Double,z:Double,p:ResearchColors,scale:Double=1){
        let base=project(x,0,z)
        c.saveGState();c.translateBy(x:base.x,y:base.y);c.scaleBy(x:scale,y:scale);c.translateBy(x:-base.x,y:-base.y);defer{c.restoreGState()}
        WorldInk.softShadow(c,CGPoint(x:base.x,y:base.y-2),136,38,p.dark,0.66)
        let seat=WorldInk.blend(p.stone,p.paper,0.14)
        // Five caster spokes, a pedestal, an upholstered seat, support and curved back.
        for i in 0..<5 {let a=Double(i)*Double.pi*0.4,foot=project(x+cos(a)*49,6,z+sin(a)*49)
            WorldInk.path(c,[project(x,14,z),foot],p.stone,4);WorldInk.oval(c,CGRect(x:foot.x-5,y:foot.y-6,width:11,height:2.5),p.dark,0.80);WorldInk.oval(c,CGRect(x:foot.x-5,y:foot.y-5,width:10,height:9),p.dark);WorldInk.path(c,[CGPoint(x:foot.x-3,y:foot.y+2),CGPoint(x:foot.x+3,y:foot.y+2)],p.paper,0.8,0.3)
        }
        WorldInk.path(c,[project(x,12,z),project(x,74,z)],p.paper,5,0.38)
        WorldInk.path(c,[project(x-1,22,z),project(x-1,70,z)],p.lamp,0.9,0.28)
        let cushion=[project(x-33,78,z-27),project(x+35,78,z-27),project(x+35,78,z+38),project(x-33,78,z+38)]
        let seatPath=CGMutablePath();seatPath.move(to:cushion[0]);seatPath.addQuadCurve(to:cushion[1],control:CGPoint(x:(cushion[0].x+cushion[1].x)/2,y:cushion[0].y-7));seatPath.addQuadCurve(to:cushion[2],control:CGPoint(x:cushion[1].x+6,y:cushion[2].y));seatPath.addQuadCurve(to:cushion[3],control:CGPoint(x:(cushion[2].x+cushion[3].x)/2,y:cushion[2].y+3));seatPath.closeSubpath();c.saveGState();c.addPath(seatPath);c.clip()
        let seatGradient=CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),colors:[WorldInk.color(WorldInk.blend(seat,p.lamp,0.30)),WorldInk.color(seat)] as CFArray,locations:[0,1])!
        c.drawLinearGradient(seatGradient,start:cushion[3],end:cushion[1],options:[.drawsBeforeStartLocation,.drawsAfterEndLocation]);c.restoreGState()
        WorldInk.path(c,[cushion[0],cushion[1]],p.paper,2,0.28)
        WorldInk.path(c,[project(x+24,80,z+32),project(x+24,133,z+45)],p.stone,6)
        let back=[project(x-36,100,z+39),project(x+33,100,z+39),project(x+40,165,z+48),project(x-36,165,z+48)]
        let backPath=CGMutablePath();backPath.move(to:back[0]);backPath.addQuadCurve(to:back[1],control:CGPoint(x:(back[0].x+back[1].x)/2,y:back[0].y-6));backPath.addQuadCurve(to:back[2],control:CGPoint(x:back[2].x+7,y:(back[1].y+back[2].y)/2));backPath.addQuadCurve(to:back[3],control:CGPoint(x:(back[2].x+back[3].x)/2,y:back[3].y+17));backPath.addQuadCurve(to:back[0],control:CGPoint(x:back[3].x-7,y:(back[3].y+back[0].y)/2));c.saveGState();c.addPath(backPath);c.clip()
        let backGradient=CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),colors:[WorldInk.color(WorldInk.blend(seat,p.lamp,0.35)),WorldInk.color(seat),WorldInk.color(WorldInk.blend(seat,p.dark,0.18))] as CFArray,locations:[0,0.32,1])!
        c.drawLinearGradient(backGradient,start:back[3],end:back[1],options:[.drawsBeforeStartLocation,.drawsAfterEndLocation]);c.restoreGState()
        c.addPath(backPath);c.setStrokeColor(WorldInk.color(p.paper,0.16));c.setLineWidth(1.0);c.strokePath()
        WorldInk.path(c,[project(x-22,111,z+42),project(x+22,111,z+42)],p.dark,0.7,0.30)
        for side in [-1.0,1.0] {WorldInk.path(c,[project(x+side*38,80,z+4),project(x+side*38,101,z+4),project(x+side*38,101,z+29)],p.stone,4)}
    }
}
