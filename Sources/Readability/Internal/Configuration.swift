import Foundation

/// Configuration constants for Readability algorithm
/// Based on Mozilla Readability.js implementation
enum Configuration {

    // MARK: - Flag Constants (for internal state management)

    /// Strip unlikely candidates flag
    static let flagStripUnlikelies: UInt32 = 0x1
    /// Weight classes by pattern matching flag
    static let flagWeightClasses: UInt32 = 0x2
    /// Clean conditionally flag
    static let flagCleanConditionally: UInt32 = 0x4

    // MARK: - Default Values

    /// Max number of nodes supported by this parser (0 = no limit)
    static let defaultMaxElemsToParse = 0

    /// The number of top candidates to consider when analyzing how tight
    /// the competition is among candidates.
    static let defaultNTopCandidates = 5

    /// The default number of chars an article must have to return a result
    static let defaultCharThreshold = 500

    /// Minimum number of top candidates for alternative ancestor selection
    static let minimumTopCandidates = 3

    /// Threshold ratio for alternative ancestor selection
    static let minScoreRatioForAlternative = 0.75

    // MARK: - Scoring Weights

    static let baseScoreDiv: Double = 5
    static let baseScorePre: Double = 3
    static let baseScoreTd: Double = 3
    static let baseScoreBlockquote: Double = 3
    static let baseScoreP: Double = 1

    static let textLengthScorePer100Chars: Double = 1
    static let textLengthScoreMax: Double = 3
    static let commaScore: Double = 1

    static let classWeightPositive: Double = 25
    static let classWeightNegative: Double = -25

    /// Score divider for ancestor propagation:
    /// - parent: 1 (no division)
    /// - grandparent: 2
    /// - great grandparent+: level * 3
    static let ancestorScoreDividerParent: Double = 1
    static let ancestorScoreDividerGrandparent: Double = 2
    static let ancestorScoreDividerMultiplier: Double = 3

    /// Default ancestor score multiplier (legacy, for backward compatibility)
    static let ancestorScoreMultiplier: Double = 0.5

    // MARK: - Sibling Merging Thresholds

    /// Minimum sibling score threshold (absolute minimum)
    static let siblingScoreThresholdMinimum: Double = 10

    /// Sibling score threshold as ratio of top candidate score
    static let siblingScoreThresholdRatio: Double = 0.2

    /// Content bonus for siblings with same class name as top candidate
    static let siblingClassNameBonusRatio: Double = 0.2

    // MARK: - Link Density Thresholds

    /// Link density threshold for P tag inclusion (long paragraphs)
    static let linkDensityThresholdLong: Double = 0.25

    /// Link density threshold for P tag inclusion (short paragraphs)
    static let linkDensityThresholdShort: Double = 0

    /// Min length for "long" paragraph
    static let paragraphLengthLong: Int = 80

    // MARK: - Positive Patterns (content indicators)

    static let positivePatterns = [
        "article", "body", "content", "entry", "hentry", "h-entry",
        "main", "page", "pagination", "post", "text", "blog", "story"
    ]

    // MARK: - Negative Patterns (noise indicators)

    static let negativePatterns = [
        "-ad-", "hidden", "^hid$", " hid$", " hid ", "^hid ",
        "banner", "combx", "comment", "com-", "contact",
        "foot", "footer", "footnote", "gdpr", "masthead",
        "media", "meta", "outbrain", "promo", "related", "scroll",
        "share", "shoutbox", "sidebar", "skyscraper", "sponsor",
        "shopping", "tags", "tool", "widget"
    ]

    // MARK: - Unlikely Candidates (elements to remove)

    /// Elements that are unlikely to be content
    static let unlikelyCandidates = [
        "-ad-", "ai2html", "banner", "breadcrumbs", "combx", "comment",
        "community", "cover-wrap", "disqus", "extra", "footer", "gdpr",
        "header", "legends", "menu", "related", "remark", "replies",
        "rss", "shoutbox", "sidebar", "skyscraper", "social",
        "sponsor", "supplemental", "ad-break", "agegate", "pagination",
        "pager", "popup", "yom-remote", "newsletter", "form-contents"
    ]

    /// Elements that might be content despite matching unlikely patterns
    static let okMaybeItsACandidate = [
        "and", "article", "body", "column", "content", "main",
        "mathjax", "shadow"
    ]

    /// ARIA roles that indicate non-content elements
    static let unlikelyRoles = [
        "menu", "menubar", "complementary", "navigation",
        "alert", "alertdialog", "dialog"
    ]

    // MARK: - Byline Detection

    static let bylinePatterns = [
        "byline", "author", "dateline", "writtenby", "p-author"
    ]

    // MARK: - Element Sets for DOM Manipulation

    /// Elements that should be converted to DIV when altering siblings
    static let alterToDIVExceptions = [
        "DIV", "ARTICLE", "SECTION", "P", "OL", "UL"
    ]

    /// Elements that indicate block content inside a DIV
    /// Match Mozilla `DIV_TO_P_ELEMS` exactly for output parity.
    static let divToPElements = [
        "BLOCKQUOTE", "DL", "DIV", "IMG", "OL", "P", "PRE", "TABLE", "UL"
    ]

    /// Phrasing content elements (inline elements)
    static let phrasingElements = [
        "ABBR", "AUDIO", "B", "BDO", "BR", "BUTTON", "CITE",
        "CODE", "DATA", "DATALIST", "DFN", "EM", "EMBED", "I",
        "IMG", "INPUT", "KBD", "LABEL", "MARK", "MATH", "METER",
        "NOSCRIPT", "OBJECT", "OUTPUT", "PROGRESS", "Q", "RUBY",
        "SAMP", "SCRIPT", "SELECT", "SMALL", "SPAN", "STRONG",
        "SUB", "SUP", "TEXTAREA", "TIME", "VAR", "WBR"
    ]

    // MARK: - Share Elements

    static let shareElements = [
        "share", "sharedaddy"
    ]

    // MARK: - Tags to Score

    /// Default element tags to score during grabArticle
    static let defaultTagsToScore = [
        "H2", "H3", "H4", "H5", "H6", "P", "TD", "PRE"
    ]

    // MARK: - Presentational Attributes (to remove)

    static let presentationalAttributes = [
        "align", "background", "bgcolor", "border", "cellpadding",
        "cellspacing", "frame", "hspace", "rules", "style",
        "valign", "vspace"
    ]

    /// Elements that may have deprecated size attributes
    static let deprecatedSizeAttributeElems = [
        "TABLE", "TH", "TD", "HR", "PRE"
    ]

    // MARK: - Classes to Preserve

    /// Classes that Readability sets itself and should preserve
    static let classesToPreserve = ["page"]

    // MARK: - Lazy Image Attributes

    static let lazyImageAttributes = [
        "data-src", "data-srcset", "data-original", "data-url"
    ]

    // MARK: - Video URL Patterns

    /// Default regex pattern for allowed video URLs
    static let defaultVideoRegex = "\\/\\/(www\\.)?((dailymotion|youtube|youtube-nocookie|player\\.vimeo|v\\.qq|bilibili|live.bilibili)\\.com|(archive|upload\\.wikimedia)\\.org|player\\.twitch\\.tv)"

    // MARK: - Hash URL Pattern

    /// Pattern for hash-only URLs (#anchor)
    static let hashUrlPattern = "^#.+"

    // MARK: - JSON-LD Article Types

    static let jsonLdArticleTypes = [
        "Article", "AdvertiserContentArticle", "NewsArticle",
        "AnalysisNewsArticle", "AskPublicNewsArticle",
        "BackgroundNewsArticle", "OpinionNewsArticle",
        "ReportageNewsArticle", "ReviewNewsArticle", "Report",
        "SatiricalArticle", "ScholarlyArticle", "MedicalScholarlyArticle",
        "SocialMediaPosting", "BlogPosting", "LiveBlogPosting",
        "DiscussionForumPosting", "TechArticle", "APIReference"
    ]

    // MARK: - Title Separators

    /// Characters used as title separators
    static let titleSeparators = "|\\-–—\\/\\>»"

    // MARK: - Word Count Thresholds

    static let minWordCountForTitle = 3
    static let maxWordCountForShortTitle = 4
    static let maxWordCountBeforeColon = 5

    // MARK: - Title Length Thresholds

    static let minTitleLength = 15
    static let maxTitleLength = 150

    // MARK: - HTML Escape Map

    static let htmlEscapeMap: [String: String] = [
        "lt": "<",
        "gt": ">",
        "amp": "&",
        "quot": "\"",
        "apos": "'"
    ]
}
