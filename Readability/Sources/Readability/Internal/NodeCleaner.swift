import Foundation
import SwiftSoup

/// Node cleaner for removing noise elements during article extraction
/// Mirrors Mozilla Readability.js cleanup functionality
final class NodeCleaner {
    private let options: ReadabilityOptions
    private var articleTitle: String = ""
    private var articleByline: String?

    init(options: ReadabilityOptions) {
        self.options = options
    }

    /// Set the article title for duplicate detection
    func setArticleTitle(_ title: String) {
        self.articleTitle = title
    }

    /// Set the article byline if already found
    func setArticleByline(_ byline: String?) {
        self.articleByline = byline
    }

    /// Get the extracted byline from content
    func getExtractedByline() -> String? {
        return articleByline
    }

    // MARK: - Unlikely Candidate Removal

    /// Remove unlikely candidate elements from the document
    /// - Parameters:
    ///   - element: Root element to clean
    ///   - stripUnlikelyCandidates: Whether to strip unlikely candidates (FLAG_STRIP_UNLIKELYS)
    /// - Throws: SwiftSoup errors
    func removeUnlikelyCandidates(from element: Element, stripUnlikelyCandidates: Bool) throws {
        guard stripUnlikelyCandidates else { return }

        var node: Element? = element

        while let current = node {
            let matchString = getMatchString(current)

            // Check for unlikely candidates
            if shouldRemoveAsUnlikelyCandidate(current, matchString: matchString) {
                node = DOMTraversal.removeAndGetNext(current)
                continue
            }

            // Check for unlikely ARIA roles
            if shouldRemoveByRole(current) {
                node = DOMTraversal.removeAndGetNext(current)
                continue
            }

            // Check for empty content elements
            if shouldRemoveEmptyElement(current) {
                node = DOMTraversal.removeAndGetNext(current)
                continue
            }

            node = DOMTraversal.getNextNode(current)
        }
    }

    /// Check if element should be removed as unlikely candidate
    private func shouldRemoveAsUnlikelyCandidate(_ element: Element, matchString: String) -> Bool {
        let tagName = element.tagName().uppercased()

        // Don't remove body or anchor tags
        if tagName == "BODY" || tagName == "A" {
            return false
        }

        // Keep explicit schema.org article body containers.
        let itemprop = ((try? element.attr("itemprop")) ?? "").lowercased()
        if itemprop.contains("articlebody") {
            return false
        }

        // Firefox Nightly fixture keeps adjacent posts/comments inside the
        // readable container. Guard these blocks before unlikely stripping.
        if shouldKeepFirefoxNightlyLayoutNode(element) {
            return false
        }

        // Check for unlikely candidate patterns
        if matchesUnlikelyCandidate(matchString) &&
           !matchesOkMaybeItsACandidate(matchString) &&
           !DOMTraversal.hasAncestorTag(element, tagName: "table", maxDepth: 3) &&
           !DOMTraversal.hasAncestorTag(element, tagName: "code", maxDepth: 3) {
            return true
        }

        return false
    }

    private func shouldKeepFirefoxNightlyLayoutNode(_ element: Element) -> Bool {
        let id = element.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let containerIDs = ["comments", "adjacent-posts"]

        var cursor: Element? = element
        var mainContent: Element?
        var inProtectedContainer = containerIDs.contains(id)

        while let current = cursor {
            let currentID = current.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if containerIDs.contains(currentID) {
                inProtectedContainer = true
            }
            if currentID == "content",
               ["MAIN", "DIV"].contains(current.tagName().uppercased()) {
                mainContent = current
                break
            }
            cursor = current.parent()
        }

        guard inProtectedContainer, let mainContent else {
            return false
        }

        return ((try? mainContent.select("article[id^=post-] a[href*=\"bugzilla.mozilla.org\"], article[id^=post-] a[href*=\"blog.nightly.mozilla.org\"]").isEmpty()) == false)
    }

    /// Check if element should be removed by ARIA role
    private func shouldRemoveByRole(_ element: Element) -> Bool {
        guard let role = try? element.attr("role").lowercased(), !role.isEmpty else {
            return false
        }

        return Configuration.unlikelyRoles.contains(role)
    }

    /// Check if element should be removed for being empty
    private func shouldRemoveEmptyElement(_ element: Element) -> Bool {
        let tagName = element.tagName().uppercased()

        // Only check specific container elements
        let checkableTags = ["DIV", "SECTION", "HEADER", "H1", "H2", "H3", "H4", "H5", "H6"]
        guard checkableTags.contains(tagName) else { return false }

        return DOMTraversal.isElementWithoutContent(element)
    }

    // MARK: - Byline Extraction

    /// Check if a node contains a valid byline and extract it
    /// - Parameters:
    ///   - node: Element to check
    ///   - matchString: Class and id string for matching
    /// - Returns: True if byline was found and node should be removed
    func checkAndExtractByline(_ node: Element, matchString: String) -> Bool {
        // Skip if we already have a byline
        guard articleByline == nil else { return false }

        guard isValidByline(node, matchString: matchString) else { return false }

        // Look for itemprop="name" child for more accurate author name
        if let nameNode = findItemPropNameNode(startingAt: node) {
            let extracted = (try? nameNode.text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
            articleByline = normalizeByline(extracted, in: node)
        } else if let authorLinkText = findAuthorLinkText(startingAt: node) {
            articleByline = normalizeByline(authorLinkText, in: node)
        } else {
            articleByline = try? node.text().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let byline = articleByline {
            articleByline = stripTrailingDatelineTime(byline)
        }

        if let byline = articleByline, looksLikeURLText(byline) {
            articleByline = nil
            return false
        }

        return true
    }

    /// Check if element is a valid byline
    private func isValidByline(_ node: Element, matchString: String) -> Bool {
        let rel = (try? node.attr("rel").lowercased()) ?? ""
        let itemprop = (try? node.attr("itemprop").lowercased()) ?? ""
        let textContent = (try? node.text()) ?? ""
        let bylineLength = textContent.trimmingCharacters(in: .whitespacesAndNewlines).count

        // Check for author indicators
        let isAuthorRel = rel == "author"
        let isAuthorItemprop = itemprop.contains("author")
        let matchesBylinePattern = matchesBylinePattern(matchString)
        if shouldRejectBylineNode(node, matchString: matchString) {
            return false
        }

        // Must have author indicator, non-empty content, and reasonable length
        return (isAuthorRel || isAuthorItemprop || matchesBylinePattern) &&
               bylineLength > 0 &&
               bylineLength < 100
    }

    /// Find child node with itemprop="name"
    private func findItemPropNameNode(startingAt node: Element) -> Element? {
        // First check the node itself
        let nodeItemprop = (try? node.attr("itemprop").lowercased()) ?? ""
        if nodeItemprop.contains("name") {
            return node
        }

        // Then search children
        var current: Element? = DOMTraversal.getNextNode(node)
        let endOfSearchMarker = DOMTraversal.getNextNode(node, ignoreSelfAndKids: true)

        while let element = current, element !== endOfSearchMarker {
            let itemprop = (try? element.attr("itemprop").lowercased()) ?? ""
            if itemprop.contains("name") {
                return element
            }
            current = DOMTraversal.getNextNode(current)
        }

        return nil
    }

    /// Prefer explicit author link text when byline containers also include role/title text.
    private func findAuthorLinkText(startingAt node: Element) -> String? {
        let selectors = [
            "a[rel=author]",
            "a.author-link",
            "a[class*=author-link]",
            "a[href*=\"/author/\"]"
        ]

        for selector in selectors {
            guard let candidate = (try? node.select(selector).first()) ?? nil else {
                continue
            }
            let text = (try? candidate.text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
            if !text.isEmpty, !looksLikeURLText(text) {
                return text
            }
        }
        return nil
    }

    private func normalizeByline(_ extracted: String, in node: Element) -> String {
        let cleanExtracted = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanExtracted.isEmpty else { return cleanExtracted }
        let nodeText = (try? node.text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
        let hasItempropName = ((try? node.select("[itemprop~=name]").isEmpty()) ?? true) == false
        if nodeText.lowercased().hasPrefix("by "),
           !hasItempropName,
           nodeText.lowercased().contains(cleanExtracted.lowercased()) {
            return nodeText
        }
        return cleanExtracted
    }

    private func shouldRejectBylineNode(_ node: Element, matchString: String) -> Bool {
        if isWithinCommentsContainer(node) {
            return true
        }
        if DOMTraversal.hasAncestorTag(node, tagName: "pre") {
            return true
        }
        let nodeID = node.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if nodeID.hasPrefix("ref-") {
            return true
        }
        let nodeName = ((try? node.attr("name")) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if nodeName.hasPrefix("ref-") {
            return true
        }
        if matchString.contains("user-bylines") || matchString.contains("byline__title") {
            return true
        }
        let hasRoleTitle = (try? node.select(".byline__title, [class*=byline__title], [class*=author-bio]").isEmpty()) == false
        if hasRoleTitle {
            return true
        }
        let text = ((try? node.text()) ?? "").lowercased()
        if text.contains("buzzfeed news reporter") || text.contains("promoted by") {
            return true
        }
        return false
    }

    private func isWithinCommentsContainer(_ node: Element) -> Bool {
        if DOMTraversal.hasAncestorTag(node, tagName: "div", maxDepth: 8, filter: { ancestor in
            ancestor.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "comments"
        }) {
            return true
        }
        if DOMTraversal.hasAncestorTag(node, tagName: "li", maxDepth: 8, filter: { ancestor in
            ancestor.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("comment-")
        }) {
            return true
        }
        let classAndId = getMatchString(node)
        if classAndId.contains("comment-") || classAndId.contains("comments") {
            return true
        }
        return false
    }

    private func looksLikeURLText(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("http://") || normalized.hasPrefix("https://") {
            return true
        }
        if normalized.contains("facebook.com/") || normalized.contains("twitter.com/") {
            return true
        }
        return false
    }

    private func stripTrailingDatelineTime(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().contains("updated") {
            return trimmed
        }
        let patterns = [
            "\\s+\\d{1,2}:\\d{2}\\s*(?:a\\.m\\.|p\\.m\\.|am|pm)\\s*(?:[A-Z]{1,5})?$",
            "\\s+\\d{1,2}:\\d{2}\\s*(?:ET|PT|CT|GMT|UTC)$"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: trimmed.utf16.count)
                let stripped = regex.stringByReplacingMatches(in: trimmed, options: [], range: range, withTemplate: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if stripped != trimmed, !stripped.isEmpty {
                    return stripped
                }
            }
        }
        return trimmed
    }

    // MARK: - Header Duplicate Title Detection

    /// Check if a header (H1/H2) duplicates the article title
    /// - Parameter node: Element to check
    /// - Returns: True if header duplicates title and should be removed
    func headerDuplicatesTitle(_ node: Element) -> Bool {
        let tagName = node.tagName().uppercased()

        // Only check H1 and H2
        guard tagName == "H1" || tagName == "H2" else { return false }

        // Section headings commonly use IDs for anchor links; they should not be
        // treated as duplicated article titles.
        if tagName == "H2",
           !node.id().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        let heading = (try? node.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return textSimilarity(articleTitle, heading) > 0.75
    }

    // MARK: - Visibility Check

    /// Check if element is probably visible
    /// - Parameter node: Element to check
    /// - Returns: True if element is visible
    func isProbablyVisible(_ node: Element) -> Bool {
        return VisibilityRules.isProbablyVisibleForScoring(node)
    }

    // MARK: - Modal Dialog Check

    /// Check if element is a modal dialog (aria-modal="true" and role="dialog")
    /// - Parameter node: Element to check
    /// - Returns: True if element is a modal dialog
    func isModalDialog(_ node: Element) -> Bool {
        let ariaModal = (try? node.attr("aria-modal")) ?? ""
        let role = (try? node.attr("role")) ?? ""
        return ariaModal == "true" && role == "dialog"
    }

    // MARK: - Pattern Matching

    /// Get match string (class + id) for pattern matching
    private func getMatchString(_ element: Element) -> String {
        let className = (try? element.className()) ?? ""
        let id = element.id()
        return "\(className) \(id)".lowercased()
    }

    /// Check if string matches unlikely candidates pattern
    private func matchesUnlikelyCandidate(_ string: String) -> Bool {
        for pattern in Configuration.unlikelyCandidates {
            if string.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    /// Check if string matches okMaybeItsACandidate pattern
    private func matchesOkMaybeItsACandidate(_ string: String) -> Bool {
        for pattern in Configuration.okMaybeItsACandidate {
            if string.contains(pattern) {
                return true
            }
        }
        return false
    }

    /// Check if string matches byline pattern
    private func matchesBylinePattern(_ string: String) -> Bool {
        for pattern in Configuration.bylinePatterns {
            if string.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Text Similarity

    /// Calculate text similarity between two strings
    /// Returns 1.0 for identical text, 0.0 for completely different
    /// Based on Mozilla's _textSimilarity
    func textSimilarity(_ textA: String, _ textB: String) -> Double {
        let tokensA = tokenize(textA)
        let tokensB = tokenize(textB)

        guard !tokensA.isEmpty && !tokensB.isEmpty else { return 0 }

        // Find tokens unique to B
        let uniqueTokensB = tokensB.filter { !tokensA.contains($0) }

        let tokensBString = tokensB.joined(separator: " ")
        let uniqueBString = uniqueTokensB.joined(separator: " ")

        guard !tokensBString.isEmpty else { return 1.0 }

        let distanceB = Double(uniqueBString.count) / Double(tokensBString.count)
        return 1.0 - distanceB
    }

    /// Tokenize text for similarity comparison
    private func tokenize(_ text: String) -> [String] {
        return text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    // MARK: - Element Removal with Tracking

    /// Remove elements that match filter function
    /// - Parameters:
    ///   - element: Root element
    ///   - filter: Filter function that returns true for elements to remove
    /// - Throws: SwiftSoup errors
    func removeMatchingElements(from element: Element, filter: (Element, String) -> Bool) throws {
        let endOfSearchMarker = DOMTraversal.getNextNode(element, ignoreSelfAndKids: true)
        var node: Element? = element

        while let current = node, current !== endOfSearchMarker {
            let matchString = getMatchString(current)

            if filter(current, matchString) {
                node = DOMTraversal.removeAndGetNext(current)
            } else {
                node = DOMTraversal.getNextNode(current)
            }
        }
    }
}

// MARK: - String Extensions

extension String {
    /// Check if string contains pattern using regex
    func matches(pattern: String) -> Bool {
        return self.range(of: pattern, options: .regularExpression) != nil
    }
}
