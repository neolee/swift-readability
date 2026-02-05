import Foundation

/// Configuration options for Readability parsing
public struct ReadabilityOptions: Sendable {
    /// Maximum number of elements to parse (0 = no limit)
    public var maxElemsToParse: Int

    /// Number of top candidates to consider for article extraction
    public var nbTopCandidates: Int

    /// Minimum character count for valid content
    public var charThreshold: Int

    /// Preserve CSS classes in output HTML
    public var keepClasses: Bool

    /// Disable JSON-LD metadata parsing
    public var disableJSONLD: Bool

    /// Classes to preserve in the output (in addition to defaults)
    public var classesToPreserve: [String]

    /// Custom serializer function for HTML output (nil = use default)
    /// Note: In Swift, we use a simpler approach - this is reserved for future use
    public var useCustomSerializer: Bool

    /// Regex pattern for allowed video URLs
    public var allowedVideoRegex: String

    /// Modifier for link density calculation
    public var linkDensityModifier: Double

    /// Enable debug logging
    public var debug: Bool

    /// Creates a new ReadabilityOptions instance with default values
    public init(
        maxElemsToParse: Int = 0,
        nbTopCandidates: Int = 5,
        charThreshold: Int = 500,
        keepClasses: Bool = false,
        disableJSONLD: Bool = false,
        classesToPreserve: [String] = [],
        useCustomSerializer: Bool = false,
        allowedVideoRegex: String = "",
        linkDensityModifier: Double = 0.0,
        debug: Bool = false
    ) {
        self.maxElemsToParse = maxElemsToParse
        self.nbTopCandidates = nbTopCandidates
        self.charThreshold = charThreshold
        self.keepClasses = keepClasses
        self.disableJSONLD = disableJSONLD
        self.classesToPreserve = classesToPreserve
        self.useCustomSerializer = useCustomSerializer
        self.allowedVideoRegex = allowedVideoRegex.isEmpty
            ? "\\/\\/(www\\.)?(youtube\\.com|youtu\\.be|player\\.vimeo\\.com|vimeo\\.com|dailymotion\\.com|soundcloud\\.com|wistia\\.net|podigee\\.io|simplecast\\.com|podbean\\.com|mixcloud\\.com|embed\\.spotify\\.com|captivate\\.fm|player\\.captivate\\.fm)"
            : allowedVideoRegex
        self.linkDensityModifier = linkDensityModifier
        self.debug = debug
    }

    /// Default options instance
    public static let `default` = ReadabilityOptions()
}
