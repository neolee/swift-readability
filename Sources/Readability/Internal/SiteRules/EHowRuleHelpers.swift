import Foundation
import SwiftSoup

enum EHowRuleHelpers {
    /// Remove eHow legacy headline siblings when author profile + score modules are present.
    /// Shared by eHow unwanted/serialization rules to avoid drift between duplicated logic.
    static func removeLegacyHeadlineSiblings(in articleContent: Element) throws {
        for container in try articleContent.select("div") {
            let children = container.children().array()
            let hasAuthorProfile = children.contains { child in
                child.tagName().lowercased() == "div" &&
                    ((try? child.attr("data-type")) ?? "").lowercased() == "authorprofile"
            }
            guard hasAuthorProfile else { continue }

            let hasScoreBlock = children.contains { child in
                child.tagName().lowercased() == "div" &&
                    ((try? child.attr("data-score")) ?? "").lowercased() == "true"
            }
            guard hasScoreBlock else { continue }

            for headline in children where
                (headline.tagName().lowercased() == "h1" || headline.tagName().lowercased() == "h2") &&
                ((try? headline.attr("itemprop")) ?? "").lowercased().contains("headline") {
                try headline.remove()
            }
        }
    }
}
