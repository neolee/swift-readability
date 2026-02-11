import Foundation
import SwiftSoup

/// Drops Tumblr byline when it is just the blog handle.
///
/// SiteRule Metadata:
/// - Scope: Tumblr blogs
/// - Phase: byline normalization
/// - Trigger: host suffix `.tumblr.com` and byline equals blog slug (or `@slug`)
/// - Evidence: `realworld/tumblr`
/// - Risk if misplaced: low-value handle byline leaks into output
enum TumblrBlogHandleBylineRule: BylineSiteRule {
    static let id = "tumblr-blog-handle-byline"

    static func apply(byline: String?, sourceURL: URL?, document _: Document) throws -> String? {
        let normalizedByline = byline?.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = sourceURL?.host?.lowercased() ?? ""
        guard host.hasSuffix(".tumblr.com"), let candidate = normalizedByline?.lowercased() else {
            return normalizedByline
        }

        let blogName = host.replacingOccurrences(of: ".tumblr.com", with: "")
        if candidate == blogName || candidate == "@\(blogName)" {
            return nil
        }
        return normalizedByline
    }
}
