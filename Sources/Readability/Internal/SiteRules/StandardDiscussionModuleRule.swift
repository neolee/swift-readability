import Foundation
import SwiftSoup

/// Removes standard third-party comment/discussion platform root containers
/// before candidate scoring.
///
/// These containers embed external comment widgets and never contain article
/// content. Removing them pre-extraction prevents comment threads from
/// out-scoring short articles when `FLAG_STRIP_UNLIKELYS` and `FLAG_WEIGHT_CLASSES`
/// are disabled in multi-pass fallback (Pass 3).
///
/// SiteRule Metadata:
/// - Scope: Standard comment platform containers (Substack, Disqus)
/// - Phase: `preExtraction`
/// - Trigger:
///   Substack: `div#discussion` containing `div#substack-comments`, gated
///     by source URL host ending with `.substack.com`.
///   Disqus: `div#disqus_thread` (canonical Disqus embed target, no gate needed).
/// - Evidence: `CLI/.staging/garymarcus-3`
/// - Risk if misplaced: comment threads out-score short article bodies in Pass 3
enum StandardDiscussionModuleRule: PreExtractionDocumentRule {
    static let id = "standard-discussion-module"

    static func apply(to document: Document, sourceURL: URL?) throws {
        try removeSubstackDiscussion(from: document, sourceURL: sourceURL)
        try removeDisqusThread(from: document)
    }

    // MARK: - Substack

    private static func removeSubstackDiscussion(
        from document: Document,
        sourceURL: URL?
    ) throws {
        guard isSubstack(sourceURL) else { return }

        for discussion in try document.select("div#discussion").reversed() {
            let hasSubstackComments =
                (try? discussion.select("div#substack-comments").isEmpty()) == false
            guard hasSubstackComments else { continue }
            try discussion.remove()
        }
    }

    private static func isSubstack(_ sourceURL: URL?) -> Bool {
        guard let host = sourceURL?.host?.lowercased() else { return false }
        return host == "substack.com" || host.hasSuffix(".substack.com")
    }

    // MARK: - Disqus

    /// Remove canonical Disqus embed roots.
    ///
    /// `div#disqus_thread` is the universal Disqus embed target and has
    /// extremely low false-positive risk. No source URL gate is needed.
    private static func removeDisqusThread(from document: Document) throws {
        for thread in try document.select("div#disqus_thread").reversed() {
            let parent = thread.parent()
            try thread.remove()

            // Clean up the parent wrapper when it becomes an empty, anonymous div.
            if let parent,
               parent.children().isEmpty(),
               parent.tagName().uppercased() == "DIV",
               ((try? parent.className()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               parent.id().isEmpty {
                try parent.remove()
            }
        }
    }
}
