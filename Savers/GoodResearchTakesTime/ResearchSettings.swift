import Foundation

enum ResearchLore:String,CaseIterable,Codable {case pureArt,subtle,deepLore;var title:String {self == .pureArt ? "Pure Art":self == .deepLore ? "Deep Lore":"Subtle"}}
enum ResearchPace:String,CaseIterable,Codable {case glacial,patient,almostHasty;var title:String {self == .almostHasty ? "Almost Hasty":rawValue.capitalized};var rate:Double {self == .glacial ? 0.65:self == .patient ? 1:1.3}}
enum ResearchEnvironment:String,CaseIterable,Codable {case cave,archive,deepLab,random;var title:String {self == .deepLab ? "Deep Lab":rawValue.capitalized}}
enum ResearchActivity:String,CaseIterable,Codable {case sparse,balanced,busy;var count:Int {self == .sparse ? 2:self == .balanced ? 4:6}}
enum ResearchMazePresence:String,CaseIterable,Codable {case rare,balanced,frequent}
enum ResearchText:String,CaseIterable,Codable {case minimal,normal,lore}
enum ResearchPalette:String,CaseIterable,Codable {case cave,deepResearch,sodium,archive,coldLab,monochrome
    var title:String {self == .deepResearch ? "Deep Research":self == .coldLab ? "Cold Lab":rawValue.capitalized}
    var colors:ResearchColors {
        switch self {
        case .cave:return .init(dark:RGB(0.032,0.04,0.05),stone:RGB(0.16,0.20,0.22),paper:RGB(0.71,0.70,0.58),lamp:RGB(0.95,0.65,0.31),screen:RGB(0.46,0.68,0.58))
        case .deepResearch:return .init(dark:RGB(0.025,0.037,0.065),stone:RGB(0.12,0.19,0.26),paper:RGB(0.60,0.69,0.73),lamp:RGB(0.61,0.69,0.89),screen:RGB(0.40,0.71,0.74))
        case .sodium:return .init(dark:RGB(0.045,0.036,0.025),stone:RGB(0.23,0.20,0.15),paper:RGB(0.74,0.67,0.51),lamp:RGB(1,0.64,0.27),screen:RGB(0.75,0.64,0.43))
        case .archive:return .init(dark:RGB(0.08,0.075,0.065),stone:RGB(0.29,0.27,0.23),paper:RGB(0.82,0.78,0.66),lamp:RGB(0.90,0.73,0.45),screen:RGB(0.48,0.65,0.69))
        case .coldLab:return .init(dark:RGB(0.035,0.048,0.062),stone:RGB(0.23,0.29,0.33),paper:RGB(0.73,0.79,0.80),lamp:RGB(0.78,0.85,0.81),screen:RGB(0.52,0.73,0.78))
        case .monochrome:return .init(dark:RGB(0.035,0.038,0.04),stone:RGB(0.22,0.23,0.24),paper:RGB(0.77,0.77,0.73),lamp:RGB(0.91,0.89,0.79),screen:RGB(0.67,0.72,0.70))
        }
    }
}
struct ResearchColors {let dark:RGB,stone:RGB,paper:RGB,lamp:RGB,screen:RGB}
struct ResearchSettings:Codable,Equatable {
    var lore=ResearchLore.subtle
    var pace=ResearchPace.patient
    var environment=ResearchEnvironment.random
    var palette=ResearchPalette.cave
    var activity=ResearchActivity.balanced
    var mazes=ResearchMazePresence.balanced
    var text=ResearchText.normal
    var seedBehavior=ArtSeed.fresh
    var seed:UInt64=42
    func sanitized()->Self {self}
}
