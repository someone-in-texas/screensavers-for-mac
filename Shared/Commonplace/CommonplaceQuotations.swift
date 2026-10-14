import Foundation

/// Human-verified public-domain extracts. Model suggestions never enter this
/// catalogue automatically. Literary dialogue is attributed to its speaker.
struct CommonplaceQuotation {
    let text:String
    let attribution:String
    let source:URL
    let subject:String
    static let verified:[Self] = [
        .init(text:"Our life is frittered away by detail.",attribution:"Henry David Thoreau · Walden (1854)",source:URL(string:"https://www.gutenberg.org/files/205/205-h/205-h.htm")!,subject:"everyday"),
        .init(text:"Ah! there is nothing like staying at home for real comfort.",attribution:"Mrs. Elton, in Jane Austen's Emma (1815)",source:URL(string:"https://www.gutenberg.org/cache/epub/158/pg158-images.html")!,subject:"home"),
        .init(text:"It is interesting to contemplate an entangled bank, clothed with many plants of many kinds…",attribution:"Charles Darwin · On the Origin of Species (1859), excerpt",source:URL(string:"https://www.gutenberg.org/files/1228/1228-h/1228-h.htm")!,subject:"botany")
    ]
}
