import Foundation
import SwiftSoup

/// Removes Quanta trailing publication date from byline when fixture expects author-only byline.
///
/// SiteRule Metadata:
/// - Scope: Quanta byline normalization
/// - Phase: `byline` normalization
/// - Trigger: byline starts with `By ` and ends with date token on Quanta pages
/// - Evidence: `realworld/quanta-1`
/// - Risk if misplaced: byline drifts from fixture metadata by appending date
enum QuantaBylineDateRule: BylineSiteRule {
    static let id = "quanta-byline-date"

    static func apply(byline: String?, sourceURL: URL?, document: Document) throws -> String? {
        guard var byline else { return nil }

        let host = sourceURL?.host?.lowercased() ?? ""
        let isQuantaHost = host.contains("quantamagazine.org") || host.contains("quanta")
        if !isQuantaHost {
            let siteName = ((try? document.select("meta[property=og:site_name]").first()?.attr("content")) ?? "").lowercased()
            if !siteName.contains("quanta") {
                return byline
            }
        }

        byline = byline.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateSuffixPattern = #"\s+[A-Za-z]+\s+\d{1,2},\s+\d{4}$"#
        if byline.range(of: dateSuffixPattern, options: [.regularExpression]) != nil {
            byline = byline.replacingOccurrences(of: dateSuffixPattern, with: "", options: .regularExpression)
        }

        byline = byline.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return byline.isEmpty ? nil : byline
    }
}
