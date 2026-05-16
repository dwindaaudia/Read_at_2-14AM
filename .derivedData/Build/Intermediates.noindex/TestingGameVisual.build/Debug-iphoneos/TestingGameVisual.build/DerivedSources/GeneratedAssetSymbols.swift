import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "IMG02" asset catalog image resource.
    static let IMG_02 = DeveloperToolsSupport.ImageResource(name: "IMG02", bundle: resourceBundle)

    /// The "alex n friend" asset catalog image resource.
    static let alexNFriend = DeveloperToolsSupport.ImageResource(name: "alex n friend", bundle: resourceBundle)

    /// The "alex pp" asset catalog image resource.
    static let alexPp = DeveloperToolsSupport.ImageResource(name: "alex pp", bundle: resourceBundle)

    /// The "glass_crack" asset catalog image resource.
    static let glassCrack = DeveloperToolsSupport.ImageResource(name: "glass_crack", bundle: resourceBundle)

    /// The "ls_wallpaper" asset catalog image resource.
    static let lsWallpaper = DeveloperToolsSupport.ImageResource(name: "ls_wallpaper", bundle: resourceBundle)

    /// The "shadow_face" asset catalog image resource.
    static let shadowFace = DeveloperToolsSupport.ImageResource(name: "shadow_face", bundle: resourceBundle)

    /// The "static_noise" asset catalog image resource.
    static let staticNoise = DeveloperToolsSupport.ImageResource(name: "static_noise", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "IMG02" asset catalog image.
    static var IMG_02: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .IMG_02)
#else
        .init()
#endif
    }

    /// The "alex n friend" asset catalog image.
    static var alexNFriend: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .alexNFriend)
#else
        .init()
#endif
    }

    /// The "alex pp" asset catalog image.
    static var alexPp: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .alexPp)
#else
        .init()
#endif
    }

    /// The "glass_crack" asset catalog image.
    static var glassCrack: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .glassCrack)
#else
        .init()
#endif
    }

    /// The "ls_wallpaper" asset catalog image.
    static var lsWallpaper: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .lsWallpaper)
#else
        .init()
#endif
    }

    /// The "shadow_face" asset catalog image.
    static var shadowFace: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .shadowFace)
#else
        .init()
#endif
    }

    /// The "static_noise" asset catalog image.
    static var staticNoise: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .staticNoise)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "IMG02" asset catalog image.
    static var IMG_02: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .IMG_02)
#else
        .init()
#endif
    }

    /// The "alex n friend" asset catalog image.
    static var alexNFriend: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .alexNFriend)
#else
        .init()
#endif
    }

    /// The "alex pp" asset catalog image.
    static var alexPp: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .alexPp)
#else
        .init()
#endif
    }

    /// The "glass_crack" asset catalog image.
    static var glassCrack: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .glassCrack)
#else
        .init()
#endif
    }

    /// The "ls_wallpaper" asset catalog image.
    static var lsWallpaper: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .lsWallpaper)
#else
        .init()
#endif
    }

    /// The "shadow_face" asset catalog image.
    static var shadowFace: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .shadowFace)
#else
        .init()
#endif
    }

    /// The "static_noise" asset catalog image.
    static var staticNoise: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .staticNoise)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

