import Foundation

struct LaunchArguments {
    enum GalleryMode {
        case production
        case stub
    }

    enum FailureMode {
        case none
        case always
        case once
    }

    enum ThumbnailFailureMode {
        case none
        case once
    }

    enum FailureStep: String {
        case fail
        case success
    }

    let isUITesting: Bool
    let galleryMode: GalleryMode
    let failureMode: FailureMode
    let failureSequence: [FailureStep]
    let thumbnailFailureMode: ThumbnailFailureMode

    static func current() -> LaunchArguments {
        let processInfo = ProcessInfo.processInfo
        let arguments = processInfo.arguments
        let environment = processInfo.environment
        let isUITesting = environment["UITESTING"] == "1" || arguments.contains("UIPRESENTATION_TESTING")
        let galleryMode = resolveGalleryMode(arguments: arguments, environment: environment)
        let failureSequence = resolveFailureSequence(environment: environment)
        let failureMode = resolveFailureMode(arguments: arguments, environment: environment)
        let thumbnailFailureMode = resolveThumbnailFailureMode(environment: environment)
        return LaunchArguments(
            isUITesting: isUITesting,
            galleryMode: galleryMode,
            failureMode: failureMode,
            failureSequence: failureSequence,
            thumbnailFailureMode: thumbnailFailureMode
        )
    }

    private static func resolveGalleryMode(arguments: [String], environment: [String: String]) -> GalleryMode {
        if let override = environment["UITEST_GALLERY_MODE"], override.lowercased() == "stub" {
            return .stub
        }
        return arguments.contains("--gallery") ? .stub : .production
    }

    private static func resolveFailureSequence(environment: [String: String]) -> [FailureStep] {
        guard let value = environment["UITEST_FAILURE_SEQUENCE"] else {
            return []
        }
        return value
            .split(separator: ",")
            .compactMap { segment in
                FailureStep(rawValue: segment.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }
    }

    private static func resolveFailureMode(arguments: [String], environment: [String: String]) -> FailureMode {
        if let override = environment["UITEST_FAILURE_MODE"]?.lowercased() {
            switch override {
            case "always":
                return .always
            case "once":
                return .once
            default:
                return .none
            }
        }
        if arguments.contains("--force-network-error") {
            return .always
        }
        if arguments.contains("--force-network-error-once") {
            return .once
        }
        return .none
    }

    private static func resolveThumbnailFailureMode(environment: [String: String]) -> ThumbnailFailureMode {
        guard let value = environment["UITEST_THUMBNAIL_FAILURE"]?.lowercased() else {
            return .none
        }
        switch value {
        case "once":
            return .once
        default:
            return .none
        }
    }
}
