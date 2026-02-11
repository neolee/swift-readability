import Foundation
import SwiftSoup

/// Removes Firefox Nightly comment submission form while keeping comment list.
///
/// SiteRule Metadata:
/// - Scope: Firefox Nightly comment section form cleanup
/// - Phase: `unwanted` cleanup
/// - Trigger: `div#comments` in Nightly article container
/// - Evidence: `realworld/firefox-nightly-blog`
/// - Risk if misplaced: could strip legitimate forms from unrelated pages
enum FirefoxNightlyCommentFormRule: ArticleCleanerSiteRule {
    static let id = "firefox-nightly-comment-form"

    static func apply(to articleContent: Element, context: ArticleCleanerSiteRuleContext) throws {
        for comments in try articleContent.select("div#comments") {
            try comments.select("form, div#respond, p.comment-form-comment, p.comment-form-author, p.comment-form-email, p.form-allowed-tags, p.form-submit").remove()
        }

        // Some layouts flatten comment form wrappers and drop their original IDs.
        // Remove by stable WordPress endpoint markers as fallback.
        try articleContent.select("form#comment-form, form[action*=\"wp-comments-post.php\"], input#comment_post_ID, textarea#comment").remove()
        try articleContent.select("div#respond, h3#reply-title, p#cancel-comment-reply").remove()
    }
}
