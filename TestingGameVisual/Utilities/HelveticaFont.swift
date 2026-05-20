import SwiftUI

// MARK: - Helvetica font helper
// Single entry point for any view that needs to render text in Helvetica
// (e.g. the Files / Evidence screen). Maps SwiftUI weights to the closest
// Helvetica family member so existing call sites can keep using semantic weights.

extension Font {
    static func helvetica(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let familyName: String
        switch weight {
        case .black, .heavy, .bold, .semibold:
            familyName = "Helvetica-Bold"
        case .light, .thin, .ultraLight:
            familyName = "Helvetica-Light"
        default:
            familyName = "Helvetica"
        }
        return Font.custom(familyName, size: size)
    }
}
