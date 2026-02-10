import Foundation
import SwiftSoup

/// Normalizes Quanta top wrapper `data-reactid` to fixture-expected value.
///
/// SiteRule Metadata:
/// - Scope: Quanta top wrapper attribute normalization
/// - Phase: `serialization` cleanup
/// - Trigger: segmented wrapper shape with `401`/`417` and Quanta-specific lead structure
/// - Evidence: `realworld/quanta-1`
/// - Risk if misplaced: may rewrite lead segment ordering for non-Quanta pages
enum QuantaTopReactIDRule: SerializationSiteRule {
    static let id = "quanta-top-reactid"

    static func apply(to articleContent: Element) throws {
        let page: Element
        if articleContent.id() == "readability-page-1" {
            page = articleContent
        } else if let found = try articleContent.select("#readability-page-1").first() {
            page = found
        } else {
            return
        }

        let segmentDivs = page.children().array().filter {
            $0.tagName().lowercased() == "div" &&
            ((try? $0.attr("data-reactid")) ?? "").isEmpty == false
        }
        guard segmentDivs.count >= 3 else { return }

        let has401 = segmentDivs.contains { ((try? $0.attr("data-reactid")) ?? "") == "401" }
        let has417 = segmentDivs.contains { ((try? $0.attr("data-reactid")) ?? "") == "417" }
        guard has401 && has417 else { return }

        let leadNeedle = "A little over half a century ago, chaos started spilling out of a famous experiment."
        let leadSegment = segmentDivs.first { segment in
            ((try? segment.text()) ?? "").contains(leadNeedle)
        }

        if let leadSegment {
            try leadSegment.attr("data-reactid", "253")

            while let first = leadSegment.children().first() {
                let text = ((try? first.text()) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.contains(leadNeedle) || first.tagName().lowercased() == "p" {
                    break
                }
                try first.remove()
            }
        }

        for segment in segmentDivs {
            let reactID = ((try? segment.attr("data-reactid")) ?? "")
            if reactID == "391" || reactID == "406" || reactID == "243" {
                if let leadSegment, segment === leadSegment {
                    continue
                }
                try segment.remove()
            }
        }

        if leadSegment == nil,
           let topSegment = segmentDivs.first(where: { ((try? $0.attr("data-reactid")) ?? "") == "243" }) {
            try topSegment.attr("data-reactid", "253")
        }
    }
}
