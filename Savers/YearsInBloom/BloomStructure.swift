import AppKit

struct BloomBranch {
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint
    let birth: Double
    let width: Double
    let order: Int
    func point(_ t: Double) -> CGPoint {
        let p = min(1,max(0,t)), q = 1-p
        return CGPoint(x: q*q*start.x+2*q*p*control.x+p*p*end.x, y: q*q*start.y+2*q*p*control.y+p*p*end.y)
    }
}
struct BloomOrgan {
    let branch: Int
    let along: Double
    let angle: Double
    let length: Double
    let variation: Double
    let flower: Bool
}
struct BloomStructure {
    let species: BloomPlant
    var branches: [BloomBranch] = []
    var organs: [BloomOrgan] = []
    init(species: BloomPlant, seed: UInt64) {
        self.species = species
        var random = ArtRandom(state: seed)
        func add(_ start: CGPoint, _ end: CGPoint, _ birth: Double, _ width: Double, _ order: Int) -> Int {
            let fernCurve = species == .fern && order == 0
            var control = CGPoint(x:fernCurve ? start.x+(end.x-start.x)*0.15:(start.x+end.x)/2+(random.next()-0.5)*22, y:fernCurve ? end.y*1.22:(start.y+end.y)/2+(random.next()-0.5)*9)
            if species.evergreen && order == 1 { control.y = max(start.y,end.y)+8 }
            branches.append(BloomBranch(start:start,control:control,end:end,birth:birth,width:width,order:order))
            return branches.count-1
        }
        let height = (species.woody ? 275.0 : 180.0)*(0.82+random.next()*0.25)
        if species.evergreen {
            let trunk = add(.zero,CGPoint(x:6,y:height),0,5,0)
            for level in 0..<11 {
                let y = height*(0.12+Double(level)*0.073), spread = (height-y)*(species == .pine ? 0.38 : species == .cedar ? 0.51 : 0.44)
                for side in [-1.0,1.0] {
                    let root = branches[trunk].point(min(0.98,(y+(random.next()-0.5)*8)/height))
                    let b = add(root,CGPoint(x:root.x+side*spread*(0.70+random.next()*0.43),y:root.y+(species == .spruce ? -20:species == .pine ? -6:8)+(random.next()-0.5)*12),0.15+Double(level)*0.045,2,1)
                    for j in 0..<9 {
                        organs.append(BloomOrgan(branch:b,along:Double(j+1)/10,angle:side*0.7,length:(species == .pine ? 23:species == .cedar ? 15:18)*(0.80+random.next()*0.35),variation:random.next(),flower:false))
                    }
                }
            }
            for index in 0..<8 { organs.append(BloomOrgan(branch:trunk,along:0.86+Double(index)*0.02,angle:(index%2 == 0 ? -0.4:0.5),length:14+random.next()*7,variation:random.next(),flower:false)) }
        } else if species.woody {
            let shrubby = species == .rose || species == .sage
            let h = height*(shrubby ? 0.58:1)
            let lean = (random.next()-0.5)*44
            var trunk: [Int] = [], previous = CGPoint.zero
            for level in 0..<6 {
                let t = Double(level+1)/6
                let tip = CGPoint(x:sin(t*2.4)*lean+(random.next()-0.5)*8,y:h*t)
                trunk.append(add(previous,tip,Double(level)*0.22,7.5*(1-t*0.80),0));previous = tip
            }
            func twig(_ root:CGPoint,_ angle:Double,_ length:Double,_ depth:Int,_ birth:Double,_ width:Double) {
                let tip = CGPoint(x:root.x+sin(angle)*length,y:root.y+(species == .willow && depth == 0 ? -0.90:cos(angle))*length)
                let index = add(root,tip,birth,width,4-depth)
                if depth == 2 {
                    for leaf in 0..<4 {
                        organs.append(BloomOrgan(branch:index,along:0.25+Double(leaf)*0.22,angle:angle+(leaf%2 == 0 ? -0.8:0.8),length:11+random.next()*5,variation:random.next(),flower:false))
                    }
                }
                if depth>0 {
                    let fork = branches[index].point(0.63+random.next()*0.28)
                    let turn = 0.34+random.next()*0.43
                    twig(fork,angle-turn,length*(0.52+random.next()*0.19),depth-1,birth+0.20,width*0.55)
                    twig(tip,angle+turn*0.7,length*(0.47+random.next()*0.20),depth-1,birth+0.27,width*0.51)
                } else {
                    for leaf in 0..<5 {
                        let flower = [.dogwood,.rose,.fruitTree,.sage].contains(species) && leaf == 4
                        organs.append(BloomOrgan(branch:index,along:0.15+Double(leaf)*0.20,angle:(species == .willow ? Double.pi:angle)+(leaf%2 == 0 ? -1:1)*(0.48+random.next()*0.55),length:species == .willow ? 23:species == .sage ? 13:12+random.next()*10,variation:random.next(),flower:flower))
                    }
                }
            }
            for level in 0..<11 {
                let segment = min(5,1+level/2), t = 0.15+random.next()*0.70
                let root = branches[trunk[segment]].point(t)
                let side = level%2 == 0 ? -1.0:1.0
                let spread = species.narrow ? 0.48:species == .willow ? 1.18:species == .japaneseMaple ? 1.10:0.88
                let angle = side*(0.50+random.next()*0.55)*spread
                let length = h*(0.26+random.next()*0.13)*(1-Double(level)*0.035)
                let birth = branches[trunk[segment]].birth+0.12+t*0.20
                twig(root,angle,length,2,birth,2.9*(1-Double(level)*0.04))
            }
            let juvenile = add(branches[trunk[0]].point(0.8),CGPoint(x:-22,y:h*0.22),0.12,0.8,3)
            for i in 0..<3 { organs.append(BloomOrgan(branch:juvenile,along:0.3+Double(i)*0.3,angle:Double(i%2)*1.3-0.5,length:12,variation:random.next(),flower:false)) }
            // Terminal shoots close the crown instead of leaving a bare pole.
            twig(previous,-0.2,h*0.16,1,1.50,1.2)
        } else {
            let count = species == .sunflower ? 2+Int(random.next()*3) : species == .fern ? 9 : species == .grass ? 23 : 11
            for stem in 0..<count {
                let offset = (Double(stem)/Double(max(1,count-1))-0.5)
                let tip = CGPoint(x:offset*(species == .fern ? 260:135)+(random.next()-0.5)*18,y:height*(0.7+random.next()*0.3)*(1-abs(offset)*(species == .fern ? 1.25:0.3)))
                let b = add(CGPoint(x:offset*14,y:0),tip,Double(stem)*0.009,species == .sunflower ? 2.7:1.1,0)
                if species == .grass {
                    if stem%3 == 0 { organs.append(BloomOrgan(branch:b,along:1,angle:offset*0.5,length:17,variation:random.next(),flower:true)) }
                    continue
                }
                let leaves = species == .fern ? 14 : species == .lavender ? 8 : species == .sunflower ? 4 : 5
                for leaf in 0..<leaves {
                    for side in [-1.0,1.0] {
                        organs.append(BloomOrgan(branch:b,along:min(0.98,0.13+Double(leaf)/Double(max(1,leaves-1))*0.78+(species == .fern ? 0:side>0 ? 0.045:0)),angle:side*(0.8+random.next()*0.4)-(species == .fern ? atan2(tip.x,tip.y)*0.65:0),length:species == .fern ? (19+random.next()*10)*pow(1-Double(leaf)/Double(leaves),0.85):species == .sunflower ? 20+random.next()*6:10+random.next()*4,variation:random.next(),flower:false))
                    }
                }
                if species != .fern { organs.append(BloomOrgan(branch:b,along:1,angle:0,length:species == .sunflower ? 34:species == .coneflower ? 18:species == .lavender ? 20:13,variation:random.next(),flower:true)) }
            }
        }
    }
}
