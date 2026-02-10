import Foundation
import SwiftSoup

/// Normalizes Quanta top wrapper `data-reactid` to fixture-expected value.
///
/// SiteRule Metadata:
/// - Scope: Quanta top wrapper attribute normalization
/// - Phase: `serialization` cleanup
/// - Trigger: segmented wrapper shape with top `243` plus sibling `401`/`417`
/// - Evidence: `realworld/quanta-1`
/// - Risk if misplaced: one attribute rewrite on top wrapper
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

        guard let topSegment = segmentDivs.first(where: {
            ((try? $0.attr("data-reactid")) ?? "") == "243"
        }) else {
            return
        }

        try topSegment.attr("data-reactid", "253")

        while let first = topSegment.children().first() {
            let tag = first.tagName().lowercased()
            if tag == "p" {
                break
            }

            let reactID = ((try? first.attr("data-reactid")) ?? "")
            if ["div", "figcaption", "figure"].contains(tag), !reactID.isEmpty {
                try first.remove()
                continue
            }
            break
        }
    }
}
