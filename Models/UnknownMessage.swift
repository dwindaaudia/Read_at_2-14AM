import Foundation

struct UnknownMessage: Identifiable, Codable {
    var id = UUID()
    let text: String
}
