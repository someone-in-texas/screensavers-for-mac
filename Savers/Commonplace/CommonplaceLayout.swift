import AppKit

/// Eighteen editorial grammars, not eighteen random seeds of the same grid.
struct CommonplaceLayout {
    enum Support { case spread, sheet, card, clipping, tracing }
    let support: Support
    let note: CGRect
    let picture: CGRect
    let title: CGPoint
    let columns: Int
    let decoration: Int
    init(index:Int,width:Double,height:Double,theme:CommonplaceTheme = .sepia) {
        let body = CGRect(x:155,y:150,width:width-310,height:max(80,height-430))
        func box(_ x:Double,_ y:Double,_ w:Double,_ h:Double)->CGRect { CGRect(x:body.minX+x*body.width,y:body.minY+y*body.height,width:w*body.width,height:h*body.height) }
        let variants: [(Support,CGRect,CGRect,Int,Int)] = [
            (.spread,box(0,0.10,0.43,0.86),box(0.54,0.05,0.46,0.92),1,0),
            (.sheet,box(0.12,0.40,0.57,0.46),box(0.64,0.03,0.26,0.32),1,1),
            (.clipping,box(0,0.05,0.36,0.90),box(0.44,0,0.56,1),1,2),
            (.spread,box(0.54,0.03,0.43,0.92),box(0,0.05,0.43,0.94),1,3),
            (.card,box(0.08,0.13,0.53,0.80),box(0.69,0.17,0.27,0.60),1,4),
            (.sheet,box(0,0.12,0.38,0.86),box(0.46,0,0.54,1),1,5),
            (.clipping,box(0.05,0.05,0.90,0.90),.zero,2,6),
            (.spread,box(0,0.05,0.42,0.90),box(0.55,0.05,0.43,0.90),1,7),
            (.sheet,box(0.15,0.05,0.65,0.90),.zero,1,8),
            (.tracing,box(0,0.51,0.45,0.43),box(0.50,0,0.50,0.88),1,9),
            (.sheet,box(0.07,0.05,0.86,0.90),.zero,2,10),
            (.card,box(0,0.07,0.52,0.86),box(0.62,0.16,0.33,0.70),1,11),
            (.spread,box(0.57,0.48,0.39,0.48),box(0,0.05,0.47,0.94),1,12),
            (.sheet,box(0,0.0,1,0.21),box(0.08,0.28,0.84,0.72),2,13),
            (.clipping,box(0.04,0.09,0.38,0.85),box(0.53,0.16,0.42,0.73),1,14),
            (.card,box(0.10,0.08,0.84,0.84),.zero,2,15),
            (.sheet,box(0.18,0.12,0.58,0.80),.zero,1,16),
            (.tracing,box(0.03,0.06,0.38,0.90),box(0.48,0.18,0.45,0.75),1,17)
        ]
        var v = variants[index%variants.count]
        switch theme {
        case .naturalist: v = ([2,3,5,11,13,14].map { variants[$0] })[index%6]
        case .observatory:
            v = index%3 == 0 ? (.tracing,box(0.53,0.12,0.43,0.76),box(0.02,0.07,0.43,0.86),1,5):index%3 == 1 ? (.clipping,box(0.03,0.45,0.45,0.46),box(0.55,0.01,0.43,0.98),1,5):(.tracing,box(0.03,0.07,0.39,0.84),box(0.49,0.07,0.49,0.88),1,5)
        case .workshop:
            v = index%3 == 0 ? (.tracing,box(0.59,0.04,0.39,0.91),box(0.02,0.06,0.48,0.90),1,9):index%3 == 1 ? variants[9]:(.tracing,box(0.03,0.1,0.37,0.8),box(0.46,0.03,0.51,0.94),1,9)
        case .atomic:
            v = index%3 == 0 ? (.card,box(0.47,0.10,0.48,0.78),box(0.02,0.10,0.34,0.78),1,15):index%3 == 1 ? variants[15]:(.card,box(0.02,0.12,0.49,0.74),box(0.61,0.12,0.34,0.74),1,15)
        case .offWorld:
            v = index%3 == 0 ? variants[17]:index%3 == 1 ? variants[6]:(.sheet,box(0.06,0.07,0.45,0.86),box(0.61,0.12,0.34,0.76),1,17)
        default: break
        }
        support = v.0;note = v.1;picture = v.2;columns = v.3;decoration = v.4
        title = CGPoint(x:body.minX+(index == 8 ? body.width*0.15:0),y:height-130)
    }
}
