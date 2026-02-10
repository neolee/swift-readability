import Foundation
import SwiftSoup

/// Trims Wikia/Fandom byline trailing relative-time suffix (e.g. "• 8h").
///
/// SiteRule Metadata:
/// - Scope: Wikia/Fandom byline text cleanup
/// - Phase: byline normalization
/// - Trigger: byline contains bullet-separated relative-time suffix
/// - Evidence: `realworld/wikia`
/// - Risk if misplaced: preserves noisy timestamp in author field
enum WikiaBylineTimeSuffixRule: BylineSiteRule {
    static let id = "wikia-byline-time-suffix"

    static func apply(byline: String?, sourceURL _: URL?, document: Document) throws -> String? {
        guard let byline else { return byline }

        let siteName = ((try? document.select("meta[property='og:site_name']").first()?.attr("content")) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard siteName.contains("wikia") || siteName.contains("fandom") else {
            return byline
        }

        let compact = byline
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.contains("•") else {
            return compact
        }

        let parts = compact.split(separator: "•", maxSplits: 1, omittingEmptySubsequences: true)
        guard let author = parts.first else {
            return compact
        }
        let cleaned = String(author).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? compact : cleaned
    }
}
