import Foundation
import SwiftSoup

/// Normalizes legacy Windows file URLs from `C|` and double-encoded `%25` forms.
///
/// SiteRule Metadata:
/// - Scope: Hukumusume legacy file URL normalization
/// - Phase: `serialization` cleanup
/// - Trigger: `src` with `file:///C|/` or `file:///C%7C/` patterns
/// - Evidence: `realworld/hukumusume`
/// - Risk if misplaced: percent-encoding and drive separator drift from fixture snapshots
enum HukumusumeLegacyFileURLRule: SerializationSiteRule {
    static let id = "hukumusume-legacy-file-url"

    static func apply(to articleContent: Element) throws {
        for element in try articleContent.select("[src]") {
            var src = (try? element.attr("src")) ?? ""
            guard src.contains("file:///C|/") || src.contains("file:///C%7C/") || src.contains("Documents%2520and%2520Settings") else {
                continue
            }

            src = src.replacingOccurrences(of: "file:///C|/", with: "file:///C:/")
            src = src.replacingOccurrences(of: "file:///C%7C/", with: "file:///C:/")

            while src.contains("%25") {
                src = src.replacingOccurrences(of: "%25", with: "%")
            }

            try element.attr("src", src)
        }
    }
}
