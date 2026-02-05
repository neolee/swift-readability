import Foundation

/// Configuration constants for Readability algorithm
enum Configuration {
    // MARK: - Scoring Weights

    static let baseScoreDiv = 5.0
    static let baseScorePre = 3.0
    static let baseScoreTd = 3.0
    static let baseScoreBlockquote = 3.0
    static let baseScoreP = 1.0

    static let textLengthScorePer100Chars = 1.0
    static let textLengthScoreMax = 3.0
    static let commaScore = 1.0

    static let classWeightPositive = 25.0
    static let classWeightNegative = -25.0

    static let ancestorScoreMultiplier = 0.5

    // MARK: - Patterns

    static let positivePatterns = [
        "article", "body", "content", "entry", "hentry", "h-entry",
        "main", "page", "pagination", "post", "text", "blog", "story"
    ]

    static let negativePatterns = [
        "-ad-", "hidden", "banner", "combx", "comment", "com-",
        "contact", "foot", "footer", "footnote", "gdpr", "masthead",
        "media", "meta", "outbrain", "promo", "related", "scroll",
        "share", "shoutbox", "sidebar", "skyscraper", "sponsor",
        "shopping", "tags", "tool", "widget"
    ]

    static let unlikelyCandidates = [
        "-ad-", "ai2html", "banner", "breadcrumbs", "combx", "comment",
        "community", "cover-wrap", "disqus", "extra", "gdpr", "header",
        "legends", "menu", "related", "remark", "replies",
        "rssshub", "shoutbox", "sidebar", "skyscraper", "social",
        "sponsor", "supplemental", "ad-break", "agegate", "pagination",
        "pager", "popup", "yom-remote"
    ]

    static let okMaybeItsACandidate = [
        "and", "article", "body", "column", "main", "shadow"
    ]

    static let divToPElements = [
        "a", "blockquote", "dl", "div", "img", "ol", "p", "pre", "table", "ul"
    ]

    static let alterToDIVExceptions = [
        "div", "article", "section", "p"
    ]

    // MARK: - Default Values

    static let defaultMaxElemsToParse = 0
    static let defaultNTopCandidates = 5
    static let defaultCharThreshold = 500

    // MARK: - Flag Constants (for internal state management)

    static let flagStripUnlikelies: UInt32 = 0x1
    static let flagWeightClasses: UInt32 = 0x2
    static let flagCleanConditionally: UInt32 = 0x4
}
