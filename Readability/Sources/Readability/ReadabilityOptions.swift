import Foundation

/// Configuration options for Readability parsing
public struct ReadabilityOptions: Sendable {
    /// Maximum number of elements to parse (0 = no limit).
    /// Status: deferred/no-op. This option is not wired into the extraction pipeline yet.
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

    /// Reserved custom serializer switch.
    /// Status: deferred/no-op. The current implementation always uses built-in serialization.
    public var useCustomSerializer: Bool

    /// Regex pattern for allowed video URLs.
    /// Status: deferred/no-op. Not yet consumed by cleaning/embedding logic.
    public var allowedVideoRegex: String

    /// Modifier for link density calculation
    public var linkDensityModifier: Double

    /// Enable debug logging.
    /// Status: deferred/no-op. The core pipeline currently does not emit debug logs from this flag.
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
            ? Configuration.defaultVideoRegex
            : allowedVideoRegex
        self.linkDensityModifier = linkDensityModifier
        self.debug = debug
    }

    /// Default options instance
    public static let `default` = ReadabilityOptions()
}
