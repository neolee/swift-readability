import Foundation
import SwiftSoup

/// Restores QQ vote container id stripped during intermediate cleanup passes.
///
/// SiteRule Metadata:
/// - Scope: Tencent QQ vote widget container identity
/// - Phase: `serialization` cleanup
/// - Trigger: `span#test` inside vote prompt paragraph
/// - Evidence: `realworld/qq`
/// - Risk if misplaced: output loses expected `div#vote` structure
enum QQVoteContainerRule: SerializationSiteRule {
    static let id = "qq-vote-container"

    static func apply(to articleContent: Element) throws {
        for marker in try articleContent.select("span#test").array() {
            guard let paragraph = marker.parent(), paragraph.tagName() == "p" else {
                continue
            }
            guard let container = paragraph.parent(), container.tagName() == "div" else {
                continue
            }
            if container.id().isEmpty {
                try container.attr("id", "vote")
            }
        }
    }
}
