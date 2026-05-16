#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "IMG02" asset catalog image resource.
static NSString * const ACImageName_IMG_02 AC_SWIFT_PRIVATE = @"IMG02";

/// The "alex n friend" asset catalog image resource.
static NSString * const ACImageNameAlexNFriend AC_SWIFT_PRIVATE = @"alex n friend";

/// The "alex pp" asset catalog image resource.
static NSString * const ACImageNameAlexPp AC_SWIFT_PRIVATE = @"alex pp";

/// The "glass_crack" asset catalog image resource.
static NSString * const ACImageNameGlassCrack AC_SWIFT_PRIVATE = @"glass_crack";

/// The "ls_wallpaper" asset catalog image resource.
static NSString * const ACImageNameLsWallpaper AC_SWIFT_PRIVATE = @"ls_wallpaper";

/// The "shadow_face" asset catalog image resource.
static NSString * const ACImageNameShadowFace AC_SWIFT_PRIVATE = @"shadow_face";

/// The "static_noise" asset catalog image resource.
static NSString * const ACImageNameStaticNoise AC_SWIFT_PRIVATE = @"static_noise";

#undef AC_SWIFT_PRIVATE
