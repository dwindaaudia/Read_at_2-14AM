import Foundation

// MARK: - Runtime Environment Detection

enum RuntimeEnvironment {
    static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    static var canUseFoundationModels: Bool {
        if isRunningInPreview { return false }
#if targetEnvironment(simulator)
        return false
#else
        return true
#endif
    }
    
    static var foundationModelsDebugLabel: String {
        if isRunningInPreview { return "Preview Fallback" }
#if targetEnvironment(simulator)
        return "Simulator Fallback"
#else
        return canUseFoundationModels ? "Device Model" : "Device Fallback"
#endif
    }
}
