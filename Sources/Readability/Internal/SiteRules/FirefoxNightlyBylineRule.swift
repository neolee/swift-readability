import Foundation
import SwiftSoup

/// Restores Firefox Nightly byline from the header author link when metadata is absent.
enum FirefoxNightlyBylineRule: MetadataBylineSiteRule {
    static let id = "firefox-nightly-byline"

    static func apply(currentByline: String?, sourceURL: URL?, document: Document) throws -> String? {
        if let currentByline, !currentByline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return currentByline
        }

        guard isFirefoxNightlyDocument(document, sourceURL: sourceURL),
              let link = (try? document.select("main#content a[rel=author]").first()) ?? nil else {
            return currentByline
        }

        let text = (try? link.text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        return text.isEmpty ? currentByline : text
    }

    private static func isFirefoxNightlyDocument(_ document: Document, sourceURL: URL?) -> Bool {
        let siteName = ((try? document.select("meta[property='og:site_name']").first()?.attr("content")) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if siteName == "firefox nightly news" {
            return true
        }

        let title = ((try? document.title()) ?? "").lowercased()
        if title.contains("firefox nightly") {
            return true
        }

        let sourceHost = sourceURL?.host?.lowercased() ?? ""
        if sourceHost.contains("nightly.mozilla.org") {
            return true
        }

        return false
    }
}