import Foundation

enum StrawberryLore:String,CaseIterable,Codable {case pureArt,knowing,terminallyOnline
    var title:String {switch self {case .pureArt:return "Pure Art";case .knowing:return "Knowing";case .terminallyOnline:return "Terminally Online"}}
}
enum StrawberryBalance:String,CaseIterable,Codable {case mostlyField,balanced,moreBasement
    var title:String {switch self {case .mostlyField:return "Mostly Field";case .balanced:return "Balanced";case .moreBasement:return "More Basement"}}
}
enum StrawberryPace:String,CaseIterable,Codable {case dream,calm,restless;var rate:Double {self == .dream ? 0.65:self == .calm ? 1:1.35}}
enum StrawberryWeather:String,CaseIterable,Codable {case off,rare,normal}
enum StrawberryNetwork:String,CaseIterable,Codable {case hidden,subtle,visible}
enum StrawberryWind:String,CaseIterable,Codable {case still,gentle,breezy;var amount:Double {self == .still ? 0:self == .gentle ? 1:1.7}}
enum StrawberryDensity:String,CaseIterable,Codable {case sparse,balanced,fieldsForever;var title:String {self == .fieldsForever ? "Fields Forever":rawValue.capitalized};var count:Int {self == .sparse ? 72:self == .balanced ? 130:190}}
enum StrawberryText:String,CaseIterable,Codable {case none,rare,normal}
enum StrawberryPalette:String,CaseIterable,Codable {case strawberryNight,moonlit,terminalGarden,goldenHour,infrared,softFuture,monochromeRed
    var title:String {switch self {case .strawberryNight:return "Strawberry Night";case .terminalGarden:return "Terminal Garden";case .goldenHour:return "Golden Hour";case .softFuture:return "Soft Future";case .monochromeRed:return "Monochrome + Red";default:return rawValue.capitalized}}
    var colors:StrawberryColors {
        switch self {
        case .strawberryNight:return .init(sky:RGB(0.035,0.048,0.105),haze:RGB(0.20,0.23,0.34),leaf:RGB(0.20,0.35,0.29),fruit:RGB(0.58,0.10,0.17),light:RGB(0.91,0.68,0.39),signal:RGB(0.41,0.64,0.64))
        case .moonlit:return .init(sky:RGB(0.045,0.075,0.12),haze:RGB(0.31,0.39,0.46),leaf:RGB(0.33,0.46,0.46),fruit:RGB(0.49,0.15,0.23),light:RGB(0.80,0.85,0.81),signal:RGB(0.54,0.69,0.74))
        case .terminalGarden:return .init(sky:RGB(0.018,0.041,0.035),haze:RGB(0.10,0.20,0.16),leaf:RGB(0.24,0.46,0.33),fruit:RGB(0.61,0.13,0.16),light:RGB(0.67,0.77,0.49),signal:RGB(0.39,0.73,0.68))
        case .goldenHour:return .init(sky:RGB(0.14,0.09,0.12),haze:RGB(0.46,0.27,0.20),leaf:RGB(0.31,0.37,0.26),fruit:RGB(0.57,0.14,0.16),light:RGB(0.96,0.68,0.38),signal:RGB(0.58,0.64,0.54))
        case .infrared:return .init(sky:RGB(0.035,0.02,0.055),haze:RGB(0.22,0.10,0.22),leaf:RGB(0.25,0.18,0.30),fruit:RGB(0.66,0.15,0.33),light:RGB(0.69,0.39,0.45),signal:RGB(0.58,0.37,0.66))
        case .softFuture:return .init(sky:RGB(0.15,0.15,0.23),haze:RGB(0.45,0.39,0.45),leaf:RGB(0.40,0.51,0.42),fruit:RGB(0.72,0.33,0.35),light:RGB(0.91,0.82,0.64),signal:RGB(0.65,0.74,0.69))
        case .monochromeRed:return .init(sky:RGB(0.035,0.04,0.045),haze:RGB(0.25,0.27,0.28),leaf:RGB(0.36,0.39,0.38),fruit:RGB(0.64,0.12,0.18),light:RGB(0.82,0.82,0.76),signal:RGB(0.57,0.61,0.61))
        }
    }
}
struct StrawberryColors {let sky:RGB,haze:RGB,leaf:RGB,fruit:RGB,light:RGB,signal:RGB}
struct StrawberrySettings:Codable,Equatable {
    var lore=StrawberryLore.knowing
    var balance=StrawberryBalance.mostlyField
    var pace=StrawberryPace.calm
    var weather=StrawberryWeather.rare
    var network=StrawberryNetwork.subtle
    var palette=StrawberryPalette.strawberryNight
    var wind=StrawberryWind.gentle
    var density=StrawberryDensity.balanced
    var text=StrawberryText.rare
    var seedBehavior=ArtSeed.fresh
    var seed:UInt64=42
    func sanitized()->Self {self}
}
