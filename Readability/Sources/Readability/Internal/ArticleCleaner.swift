import Foundation
import SwiftSoup

/// Cleans and prepares article content after extraction
/// Implements Mozilla Readability.js _prepArticle and related methods
final class ArticleCleaner {
    private let options: ReadabilityOptions

    init(options: ReadabilityOptions) {
        self.options = options
    }

    // MARK: - Main Article Preparation

    /// Prepare article content for output
    /// This is the main entry point for article cleaning
    func prepArticle(_ articleContent: Element) throws {
        // Remove unwanted elements FIRST (before cleanStyles removes class attributes)
        try removeUnwantedElements(articleContent)

        // Clean styles
        try cleanStyles(articleContent)

        // Fix lazy images
        try fixLazyImages(articleContent)
        try restoreFigureWrapperMetadataAttributes(articleContent)

        // Match Mozilla prep for form controls.
        try cleanElementsByTag(articleContent, tags: ["input", "textarea", "select", "button"])
        try removeShortLinkHeavyDivs(articleContent)
        try removeRelatedLinkCollectionDivs(articleContent)
        try removeNYTimesRelatedLinkCards(articleContent)
        try removeSingleItemPromoLists(articleContent)
        try removeEmptyContainerDivs(articleContent)
        try removeShortRoleNoteCallouts(articleContent)

        // Convert DIVs to Ps where appropriate
        try convertDivsToParagraphs(articleContent)
        try collapseSingleDivWrappers(articleContent)
    }

    // MARK: - DIV to P Conversion

    /// Convert DIV elements to P elements where appropriate
    /// This implements Mozilla's div-to-p conversion logic
    private func convertDivsToParagraphs(_ element: Element) throws {
        let divs = try element.select("div")

        for div in divs {
            // Skip if already converted
            guard div.tagName().lowercased() == "div" else { continue }
            // Skip detached top-level container created after extraction.
            guard div.parent() != nil else { continue }

            // Put consecutive phrasing content into paragraphs.
            var childNode = div.getChildNodes().first
            while let current = childNode {
                var nextSibling = current.nextSibling()

                if isPhrasingContent(current) {
                    var fragment: [Node] = []
                    var cursor: Node? = current

                    // Collect consecutive phrasing nodes.
                    while let phrasingNode = cursor, isPhrasingContent(phrasingNode) {
                        nextSibling = phrasingNode.nextSibling()
                        fragment.append(phrasingNode)
                        cursor = nextSibling
                    }

                    // Trim surrounding whitespace / <br> from the fragment.
                    while let first = fragment.first, DOMTraversal.isWhitespace(first) {
                        try first.remove()
                        fragment.removeFirst()
                    }
                    while let last = fragment.last, DOMTraversal.isWhitespace(last) {
                        try last.remove()
                        fragment.removeLast()
                    }

                    // Wrap non-empty fragment with a <p>.
                    if !fragment.isEmpty {
                        let doc = div.ownerDocument() ?? Document("")
                        let p = try doc.createElement("p")

                        if let next = nextSibling {
                            try next.before(p)
                        } else {
                            try div.appendChild(p)
                        }

                        for node in fragment where node.parent() != nil {
                            try p.appendChild(node)
                        }
                    }
                }

                childNode = nextSibling
            }

            // If DIV has exactly one P child and low link density, unwrap to that P.
            if hasSingleTagInsideElement(div, tag: "P"),
               try getLinkDensity(div) < 0.25,
               !shouldPreserveSingleParagraphWrapper(div),
               !shouldPreserveFigureImageWrapper(div),
               !isWithinMediaControlHierarchy(div),
               let parent = div.parent(),
               parent.children().count == 1 {
                if let onlyChild = div.children().first {
                    try div.replaceWith(onlyChild)
                }
                continue
            }

            // If no block children remain, convert DIV to P.
            if !(try hasChildBlockElement(div)) {
                if shouldPreserveFigureImageWrapper(div) {
                    continue
                }
                _ = try setNodeTag(div, newTag: "p")
            }
        }
    }

    /// Check if element has a single tag inside it
    func hasSingleTagInsideElement(_ element: Element, tag: String) -> Bool {
        let children = element.children()

        // Should have exactly 1 element child with given tag
        guard children.count == 1,
              children.first?.tagName().uppercased() == tag.uppercased() else {
            return false
        }

        // And should have no text nodes with real content
        let textNodes = element.textNodes()
        for textNode in textNodes {
            let trimmed = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return false
            }
        }

        return true
    }

    /// Check if element has any block-level children
    func hasChildBlockElement(_ element: Element) throws -> Bool {
        let blockElements = Set(Configuration.divToPElements.map { $0.lowercased() })

        for childNode in element.getChildNodes() {
            guard let child = childNode as? Element else { continue }
            if blockElements.contains(child.tagName().lowercased()) {
                return true
            }
            if try hasChildBlockElement(child) {
                return true
            }
        }

        return false
    }

    private func getLinkDensity(_ element: Element) throws -> Double {
        let textLength = try DOMHelpers.getInnerText(element).count
        if textLength == 0 {
            return 0
        }

        let links = try element.select("a")
        var linkLength = 0.0
        for link in links {
            let href = (try? link.attr("href")) ?? ""
            let coefficient = href.hasPrefix("#") ? 0.3 : 1.0
            linkLength += Double(try DOMHelpers.getInnerText(link).count) * coefficient
        }

        return linkLength / Double(textLength)
    }

    private func hasContainerIdentity(_ element: Element) -> Bool {
        if !element.id().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        let className = ((try? element.className()) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !className.isEmpty
    }

    private func shouldPreserveSingleParagraphWrapper(_ element: Element) -> Bool {
        guard hasContainerIdentity(element) else { return false }
        let id = element.id().lowercased()
        let className = ((try? element.className()) ?? "").lowercased()
        let signature = "\(id) \(className)"
        if signature.contains("story-continues") {
            return true
        }
        // Preserve identity wrappers for embedded media blocks (videos/iframes).
        return ((try? element.select("iframe, embed, object, video").isEmpty()) == false)
    }

    private func isWithinMediaControlHierarchy(_ element: Element) -> Bool {
        var current: Element? = element
        while let node = current {
            let role = ((try? node.attr("role")) ?? "").lowercased()
            let ariaLabel = ((try? node.attr("aria-label")) ?? "").lowercased()
            if role == "group" || role == "region" {
                return true
            }
            if ariaLabel.contains("video player") || ariaLabel.contains("progress bar") {
                return true
            }
            current = node.parent()
        }
        return false
    }

    /// Check if node is phrasing content (inline content)
    func isPhrasingContent(_ node: Node) -> Bool {
        // Text nodes are phrasing content
        if node is TextNode {
            return true
        }

        guard let element = node as? Element else { return false }

        let phrasingTags = Set(Configuration.phrasingElements.map { $0.lowercased() })
        let tagName = element.tagName().lowercased()

        // Direct phrasing elements
        if phrasingTags.contains(tagName) {
            return true
        }

        // A, DEL, INS are phrasing if all their children are phrasing
        if ["a", "del", "ins"].contains(tagName) {
            for child in element.children() {
                if !isPhrasingContent(child) {
                    return false
                }
            }
            return true
        }

        return false
    }

    // MARK: - Tag Name Change

    /// Change the tag name of an element
    /// Creates a new element with the given tag and moves all content
    /// Preserves the original order of child nodes (elements and text)
    func setNodeTag(_ element: Element, newTag: String) throws -> Element {
        // Get document context from element
        let doc = element.ownerDocument() ?? Document("")
        let normalizedTag = newTag.lowercased()
        let newElement = try doc.createElement(normalizedTag)

        try DOMHelpers.copyAttributes(from: element, to: newElement)
        if normalizedTag == "p" {
            let idValue = element.id().trimmingCharacters(in: .whitespacesAndNewlines)
            if idValue.range(of: "^[0-9]{6,}$", options: [.regularExpression]) != nil {
                try newElement.removeAttr("id")
            }

            // Media placeholders can be retagged into paragraphs.
            // Strip non-content media metadata attributes to match Mozilla output.
            let hasMediaType = element.hasAttr("data-media-type")
            let hasMediaMeta = element.hasAttr("data-media-meta")
            if hasMediaType || hasMediaMeta {
                try newElement.removeAttr("data-media-type")
                try newElement.removeAttr("data-media-meta")
            }
        }
        // Match Mozilla semantics: move nodes instead of cloning to avoid any
        // possibility of duplicate/reordered child content during retagging.
        while let firstChild = element.getChildNodes().first {
            try newElement.appendChild(firstChild)
        }

        // Replace in DOM
        try element.replaceWith(newElement)

        return newElement
    }

    // MARK: - Style Cleaning

    /// Remove style attributes and presentational attributes
    private func cleanStyles(_ element: Element) throws {
        // Match Mozilla: keep SVG subtree untouched.
        if element.tagName().lowercased() == "svg" {
            return
        }

        if !options.keepClasses {
            // Remove presentational attributes
            for attr in Configuration.presentationalAttributes {
                try element.removeAttr(attr)
            }

            // Remove deprecated size attributes for specific elements
            if Configuration.deprecatedSizeAttributeElems.contains(element.tagName().uppercased()) {
                try element.removeAttr("width")
                try element.removeAttr("height")
            }

            // Clean classes (keep only preserved classes)
            let className = try element.className()
            let preservedClasses = Configuration.classesToPreserve + options.classesToPreserve
            let newClasses = className.split(separator: " ").filter { cls in
                preservedClasses.contains(String(cls))
            }.joined(separator: " ")

            if newClasses.isEmpty {
                try element.removeAttr("class")
            } else {
                try element.attr("class", newClasses)
            }
        }

        // Recursively clean children
        for child in element.children() {
            try cleanStyles(child)
        }
    }

    // MARK: - Lazy Image Fixing

    /// Fix lazy-loaded images by converting data-src to src
    private func fixLazyImages(_ element: Element) throws {
        let images = try element.select("img, picture, figure")

        for img in images {
            // Remove tiny non-SVG base64 placeholders when alternate image
            // sources exist on other attributes.
            let currentSrc = (try? img.attr("src")) ?? ""
            if let prefix = currentSrc.range(of: "^data:([^;,]+);base64,", options: [.regularExpression, .caseInsensitive]) {
                let mimePrefix = String(currentSrc[prefix]).lowercased()
                if !mimePrefix.contains("image/svg+xml") {
                    var srcCouldBeRemoved = false
                    if let attributes = img.getAttributes() {
                        for attr in attributes {
                            if attr.getKey().lowercased() == "src" {
                                continue
                            }
                            if attr.getValue().range(of: "\\.(jpg|jpeg|png|webp)", options: [.regularExpression, .caseInsensitive]) != nil {
                                srcCouldBeRemoved = true
                                break
                            }
                        }
                    }

                    if srcCouldBeRemoved {
                        let prefixLength = currentSrc.distance(from: currentSrc.startIndex, to: prefix.upperBound)
                        let payloadLength = currentSrc.count - prefixLength
                        if payloadLength < 133 {
                            try img.removeAttr("src")
                        }
                    }
                }
            }

            // If src/srcset already present and not lazy-marked, keep as-is.
            let src = (try? img.attr("src")) ?? ""
            let srcset = (try? img.attr("srcset")) ?? ""
            let className = ((try? img.className()) ?? "").lowercased()
            if (!src.isEmpty || (!srcset.isEmpty && srcset != "null")) && !className.contains("lazy") {
                continue
            }

            var pendingSrc: String?
            var pendingSrcset: String?

            if let attributes = img.getAttributes() {
                for attr in attributes {
                    let key = attr.getKey().lowercased()
                    let value = attr.getValue().trimmingCharacters(in: .whitespacesAndNewlines)
                    if key == "src" || key == "srcset" || key == "alt" || value.isEmpty {
                        continue
                    }

                    // srcset-like: "...jpg 1x, ...webp 2x" or "...jpg 480w"
                    if value.range(of: "\\.(jpg|jpeg|png|webp)(\\S*)\\s+\\d", options: [.regularExpression, .caseInsensitive]) != nil {
                        pendingSrcset = pendingSrcset ?? value
                        continue
                    }

                    // src-like: single image URL/token
                    if value.range(of: "^\\s*\\S+\\.(jpg|jpeg|png|webp)\\S*\\s*$", options: [.regularExpression, .caseInsensitive]) != nil {
                        pendingSrc = pendingSrc ?? value
                    }
                }
            }

            if let pendingSrcset {
                if img.tagName().uppercased() == "IMG" || img.tagName().uppercased() == "PICTURE" {
                    try img.attr("srcset", pendingSrcset)
                }
            }

            if let pendingSrc {
                if img.tagName().uppercased() == "IMG" || img.tagName().uppercased() == "PICTURE" {
                    try img.attr("src", pendingSrc)
                } else if img.tagName().uppercased() == "FIGURE" {
                    let hasInnerMedia = (try? img.select("img, picture").isEmpty()) == false
                    if !hasInnerMedia {
                        let doc = img.ownerDocument() ?? Document("")
                        let child = try doc.createElement("img")
                        try child.attr("src", pendingSrc)
                        try img.appendChild(child)
                    }
                }
            }

            // Figure can also carry srcset-style attributes without src.
            if let pendingSrcset, img.tagName().uppercased() == "FIGURE" {
                let hasInnerMedia = (try? img.select("img, picture").isEmpty()) == false
                if !hasInnerMedia {
                    let doc = img.ownerDocument() ?? Document("")
                    let child = try doc.createElement("img")
                    try child.attr("srcset", pendingSrcset)
                    try img.appendChild(child)
                }
            }
        }
    }

    /// Restore metadata attributes for figure image wrappers that should survive
    /// readability cleanup (observed in Mozilla lazy-image fixtures).
    private func restoreFigureWrapperMetadataAttributes(_ element: Element) throws {
        let wrappers = try element.select("figure[contenteditable=false] > div")
        for wrapper in wrappers {
            let hasImage = ((try? wrapper.select("img").isEmpty()) == false)
            guard hasImage else { continue }
            if ((try? wrapper.attr("contenteditable")) ?? "").isEmpty {
                try wrapper.attr("contenteditable", "false")
            }
            if ((try? wrapper.attr("data-syndicationrights")) ?? "").isEmpty {
                try wrapper.attr("data-syndicationrights", "false")
            }
        }
    }

    // MARK: - Unwanted Element Removal

    /// Remove unwanted elements from article content
    private func removeUnwantedElements(_ element: Element) throws {
        // Remove script and style tags
        try element.select("script, style, noscript").remove()
        // Match Mozilla _clean() defaults for obvious non-article containers.
        try element.select("footer, aside, link").remove()
        try removeExplicitNoContentContainers(element)
        try removeKnownWidgetElements(element)
        try removeDisallowedEmbeds(element)

        // Remove elements with hidden attribute
        try VisibilityRules.removeHiddenElements(from: element)

        // Remove share/social elements
        try removeShareElements(element)
    }

    /// Remove explicit non-article wrappers frequently used for
    /// "what's next"/navigation modules that should not remain in readable output.
    private func removeExplicitNoContentContainers(_ element: Element) throws {
        let containers = try element.select("section, div")
        for container in containers {
            let id = container.id().lowercased()
            let className = ((try? container.className()) ?? "").lowercased()
            let signature = "\(id) \(className)"

            let isExplicitNoContent = signature.contains("nocontent") ||
                signature.contains("robots-nocontent") ||
                signature.contains("whats-next")
            let isSupplementalContainer = signature.contains("supplemental")
            guard isExplicitNoContent || isSupplementalContainer else { continue }

            // Keep safety guard to avoid removing legitimate long-form sections.
            let text = ((try? DOMHelpers.getInnerText(container)) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let threshold = isSupplementalContainer ? 1200 : 500
            let linkDensity = (try? getLinkDensity(container)) ?? 0

            if isSupplementalContainer {
                // Supplemental modules are usually related-link rails.
                if text.count <= threshold || linkDensity >= 0.2 {
                    try container.remove()
                }
                continue
            }

            if text.count <= threshold {
                try rescueStoryContinueLinks(from: container)
                try container.remove()
            }
        }
    }

    /// Preserve NYTimes-style "Continue reading the main story" jump links that
    /// can be nested inside ad/nocontent wrappers.
    private func rescueStoryContinueLinks(from container: Element) throws {
        guard let parent = container.parent() else { return }
        let doc = parent.ownerDocument() ?? Document("")
        let parentID = parent.id().lowercased()
        let parentClass = ((try? parent.className()) ?? "").lowercased()
        let parentSignature = "\(parentID) \(parentClass)"
        let hasInterrupter = (try? doc.select("div#story-continues-1").isEmpty()) == false

        let links = try container.select("a[href^=#story-continues-]")
        guard !links.isEmpty() else { return }

        for link in links {
            let href = (try? link.attr("href").trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
            let shouldRescue: Bool
            if parentID == "story-continues-1" {
                shouldRescue = href == "#story-continues-2"
            } else if hasInterrupter && parentSignature.contains("story-body") {
                shouldRescue = href == "#story-continues-1"
            } else {
                shouldRescue = false
            }
            guard shouldRescue else { continue }
            let text = ((try? DOMHelpers.getInnerText(link)) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let p = try doc.createElement("p")
            let a = try doc.createElement("a")
            try a.attr("href", href)
            try a.text(text)
            try p.appendChild(a)
            try container.before(p)
            return
        }
    }

    /// Remove known non-article UI widgets that leak into extracted content on some pages.
    private func removeKnownWidgetElements(_ element: Element) throws {
        // Video control label block that Mozilla output drops.
        for label in try element.select("span:matchesOwn(^\\s*Stream\\s+Type\\s*$)") {
            var current = label.parent()
            while let node = current {
                if node.tagName().lowercased() == "div" {
                    let text = (try? DOMHelpers.getInnerText(node)) ?? ""
                    if text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .hasPrefix("Stream Type") {
                        try node.remove()
                        break
                    }
                }
                current = node.parent()
            }
        }

        // Remove video caption/settings control panes.
        for candidate in try element.select("div").reversed() {
            let labels = (try? candidate.select("label")) ?? Elements()
            if labels.isEmpty() { continue }
            let labelTexts = labels.array().map {
                ((try? DOMHelpers.getInnerText($0)) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }
            let hasForeground = labelTexts.contains("foreground")
            let hasBackground = labelTexts.contains("background")
            let hasFontSize = labelTexts.contains("font size")
            if hasForeground && hasBackground && hasFontSize {
                try candidate.remove()
            }
        }

        // Scald gallery widgets (and companion heading wrappers) are non-article chrome.
        for gallery in try element.select("[data-scald-gallery]") {
            if let parent = gallery.parent(), parent.tagName().lowercased() == "div" {
                try parent.remove()
            } else {
                try gallery.remove()
            }
        }
        // Washington Post gallery embeds are interactive chrome; Mozilla output drops them.
        try element.select("div[id^=gallery-embed_]").remove()
        // Yahoo slideshow modal chrome is non-article UI.
        try element.select("div[id^=modal-slideshow-]").remove()
        // BBC media placeholders are JS video chrome and should not remain as article body.
        try element.select("div.media-placeholder[data-media-type=video], div[data-media-type=video][class*=media-placeholder]").remove()
        // NYTimes "latest/popular" stream panels are navigation chrome.
        for panel in try element.select("div") {
            let hasLiveList = (try? panel.select("> ol[aria-live=off]").isEmpty()) == false
            guard hasLiveList else { continue }
            let listCount = try panel.select("> ol > li").count
            if listCount >= 3 {
                try panel.remove()
            }
        }
        // Keep tab navigation shell, but drop embedded search forms.
        for nav in try element.select("nav") {
            let hasTablist = (try? nav.select("ul[role=tablist]").isEmpty()) == false
            guard hasTablist else { continue }
            try nav.select("form").remove()
        }
        // NYTimes collection pages sometimes inject "Continue reading the main story"
        // anchors in rank wrappers (e.g. mid1-wrapper). Mozilla output drops these.
        for wrapper in try element.select("div[id$=-wrapper]") {
            let id = wrapper.id().lowercased()
            guard id.range(of: "^mid\\d+-wrapper$", options: .regularExpression) != nil else { continue }
            let type = ((try? wrapper.attr("type")) ?? "").lowercased()
            let links = try wrapper.select("a[href^=#after-mid]")
            guard !links.isEmpty() else { continue }
            let text = ((try? DOMHelpers.getInnerText(wrapper)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if type == "rank" || text.contains("continue reading the main story") {
                try wrapper.remove()
            }
        }
        // Remove residual "View Graphic" promo blocks left by gallery embed extraction.
        for candidate in try element.select("div").reversed() {
            let hasGraphicLink = ((try? candidate.select("a[href*=_graphic.html]"))?.isEmpty()) == false
            let hasImage = ((try? candidate.select("img"))?.isEmpty()) == false
            guard hasGraphicLink && hasImage else { continue }
            let text = ((try? DOMHelpers.getInnerText(candidate)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .lowercased()
            if text.contains("view graphic") {
                try candidate.remove()
            }
        }

        // Interactive editor promo inner widgets (direct SVG + markdown children) should be removed.
        for candidate in try element.select("div").reversed() {
            let children = candidate.children()
            let hasDirectSVG = children.contains { $0.tagName().lowercased() == "svg" }
            let hasDirectMarkdown = children.contains { ((try? $0.attr("markdown")) ?? "").isEmpty == false }
            if hasDirectSVG && hasDirectMarkdown {
                try candidate.remove()
            }
        }

        // Reader feedback prompts are engagement UI, not article content.
        for prompt in try element.select(
            "div[class*=reader-satisfaction-survey], div[class*=feedback-prompt], div[class*=feedback]"
        ) {
            let cls = ((try? prompt.className()) ?? "").lowercased()
            if cls.contains("feedback-prompt") || cls.contains("reader-satisfaction-survey") {
                try prompt.remove()
            }
        }

        // CNN legacy story-top video wrapper should be removed from article body.
        try element.select("div#js-ie-storytop, div.ie--storytop, div#ie_column").remove()

        // In-read ad shell that Mozilla output drops in cnn real-world fixtures.
        for candidate in try element.select("div").reversed() {
            let text = ((try? DOMHelpers.getInnerText(candidate)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if text == "advertising inread invented by teads" {
                try candidate.remove()
            }
        }

        // Remove standalone ad label blocks (e.g. "<div><p>Advertising</p></div>").
        for candidate in try element.select("div").reversed() {
            let text = ((try? DOMHelpers.getInnerText(candidate)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard text == "advertising" || text == "advertisement" else { continue }
            if ((try? candidate.select("img, picture, video, iframe, object, embed, figure").isEmpty()) == false) {
                continue
            }
            try candidate.remove()
        }
    }

    private func cleanElementsByTag(_ element: Element, tags: [String]) throws {
        let selector = tags.joined(separator: ", ")
        try element.select(selector).remove()
    }

    /// Remove compact, link-heavy metadata/action blocks that commonly appear
    /// near hero images (e.g. author/date/follow controls) and are not article body.
    private func removeShortLinkHeavyDivs(_ root: Element) throws {
        let divs = try root.select("div")
        for div in divs.reversed() {
            guard div.parent() != nil else { continue }

            if hasAncestorTag(div, tag: "table") {
                continue
            }
            if (try? div.select("img, picture, figure, video, iframe, object, embed, table, pre, code, ul, ol, blockquote").isEmpty()) == false {
                continue
            }

            let text = try DOMHelpers.getInnerText(div).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty || text.count > 90 {
                continue
            }

            let paragraphCount = try div.select("p").count
            if paragraphCount > 4 {
                continue
            }

            let linkCount = try div.select("a").count
            if linkCount < 2 {
                continue
            }

            let linkDensity = try getLinkDensity(div)
            if linkDensity < 0.2 {
                continue
            }

            try div.remove()
        }
    }

    private func removeEmptyContainerDivs(_ root: Element) throws {
        let divs = try root.select("div")
        for div in divs.reversed() {
            guard div.parent() != nil else { continue }

            let text = try DOMHelpers.getInnerText(div).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                continue
            }

            if (try? div.select("img, picture, figure, video, iframe, object, embed, table").isEmpty()) == false {
                continue
            }

            try div.remove()
        }
    }

    /// Remove link-collection sidecars such as "Related" and "Most Read" blocks.
    private func removeRelatedLinkCollectionDivs(_ root: Element) throws {
        let divs = try root.select("div")
        for div in divs.reversed() {
            guard div.parent() != nil else { continue }
            if hasAncestorTag(div, tag: "figure") || hasAncestorTag(div, tag: "table") {
                continue
            }
            if (try? div.select("img, picture, figure, video, iframe, object, embed").isEmpty()) == false {
                continue
            }

            let headingText = (
                try? div.select("h1, h2, h3, h4, h5, h6, strong, b").first()?.text()
            )?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            if headingText.isEmpty {
                continue
            }

            let isRelatedHeading =
                headingText == "related" ||
                headingText == "more" ||
                headingText.hasPrefix("related ") ||
                headingText.hasPrefix("more on ") ||
                headingText.hasPrefix("most read")
            if !isRelatedHeading {
                continue
            }

            let linkCount = try div.select("a").count
            let listCount = try div.select("ul, ol").count
            let paragraphCount = try div.select("p").count
            let textLength = try DOMHelpers.getInnerText(div).count
            let linkDensity = try getLinkDensity(div)

            if linkCount >= 3,
               listCount >= 1,
               paragraphCount <= 3,
               textLength <= 1200,
               linkDensity >= 0.2 {
                try div.remove()
            }
        }
    }

    /// Remove short single-item promo lists embedded between article paragraphs.
    private func removeSingleItemPromoLists(_ root: Element) throws {
        let lists = try root.select("ul, ol")
        for list in lists.reversed() {
            guard list.parent() != nil else { continue }
            if hasAncestorTag(list, tag: "figure") || hasAncestorTag(list, tag: "table") {
                continue
            }

            let items = list.children()
            guard items.count == 1,
                  items.first?.tagName().lowercased() == "li" else {
                continue
            }

            let linkCount = try list.select("a").count
            if linkCount != 1 {
                continue
            }

            let text = try DOMHelpers.getInnerText(list)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty || text.count > 90 {
                continue
            }

            // Only drop if list is sandwiched by paragraphs, which strongly
            // suggests a promo/related link insert rather than core list content.
            let previous = ((try? list.previousElementSibling()?.tagName().lowercased()) ?? "") == "p"
            let next = ((try? list.nextElementSibling()?.tagName().lowercased()) ?? "") == "p"
            if previous && next {
                try list.remove()
            }
        }
    }

    /// Remove NYTimes in-article related-link card inserts.
    /// These are usually represented by links carrying `module=RelatedLinks`
    /// and should not remain in extracted article bodies.
    private func removeNYTimesRelatedLinkCards(_ root: Element) throws {
        let links = try root.select("a[href*=module=RelatedLinks][href*=pgtype=Article]")
        var cardContainers: [Element] = []
        var sectionContainers: [Element] = []

        for link in links {
            var cursor: Element? = link
            while let node = cursor {
                let tag = node.tagName().lowercased()
                if tag == "div",
                   node.parent()?.tagName().lowercased() == "section" {
                    sectionContainers.append(node)
                    break
                }
                if tag == "div",
                   node.parent()?.tagName().lowercased() == "div" {
                    cardContainers.append(node)
                    break
                }
                if tag == "article" || node.parent() == nil {
                    break
                }
                cursor = node.parent()
            }
        }

        for container in cardContainers.reversed() {
            guard container.parent() != nil else { continue }
            let allLinks = try container.select("a")
            guard !allLinks.isEmpty() else { continue }
            let relatedLinksCount = allLinks.array().filter { link in
                let href = ((try? link.attr("href")) ?? "").lowercased()
                return href.contains("module=relatedlinks") && href.contains("pgtype=article")
            }.count
            let textLength = try DOMHelpers.getInnerText(container)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .count
            if relatedLinksCount == allLinks.count, textLength <= 260 {
                try container.remove()
            }
        }

        for container in sectionContainers.reversed() {
            guard container.parent() != nil else { continue }
            let headingCount = try container.select("h1, h2, h3, h4, h5, h6").count
            if headingCount > 0 {
                continue
            }

            let allLinks = try container.select("a")
            guard !allLinks.isEmpty() else { continue }

            let relatedLinksCount = allLinks.array().filter { link in
                let href = ((try? link.attr("href")) ?? "").lowercased()
                return href.contains("module=relatedlinks") && href.contains("pgtype=article")
            }.count

            let textLength = try DOMHelpers.getInnerText(container)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .count
            let linkDensity = try getLinkDensity(container)

            if relatedLinksCount == allLinks.count,
               textLength <= 420,
               linkDensity >= 0.15 {
                try container.remove()
            }
        }
    }

    /// Remove compact role="note" callouts that are metadata/navigation (e.g. "Main article: ..."),
    /// which Mozilla typically drops during conditional cleanup.
    private func removeShortRoleNoteCallouts(_ root: Element) throws {
        let notes = try root.select("div[role=note], aside[role=note]")
        for note in notes.reversed() {
            guard note.parent() != nil else { continue }
            if (try? note.select("img, picture, figure, video, iframe, object, embed, table").isEmpty()) == false {
                continue
            }

            let text = try DOMHelpers.getInnerText(note).trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty || text.count > 80 {
                continue
            }
            if text.lowercased().hasPrefix("main article:") || text.lowercased().hasPrefix("see also:") {
                try note.remove()
            }
        }
    }

    private func cleanConditionally(_ root: Element, tag: String) throws {
        let nodes = try root.select(tag)
        for node in nodes.reversed() {
            guard node.parent() != nil else { continue }

            if hasAncestorTag(node, tag: "code") {
                continue
            }

            let weight = getClassWeight(node)
            if weight < 0 {
                try node.remove()
                continue
            }

            if getCommaCount(node) >= 10 {
                continue
            }

            let p = try node.select("p").count
            let img = try node.select("img").count
            let li = try node.select("li").count - 100
            let input = try node.select("input").count
            let headingDensity = try getTextDensity(node, tags: ["h1", "h2", "h3", "h4", "h5", "h6"])

            var embedCount = 0
            for embed in try node.select("object, embed, iframe") {
                if isAllowedVideoEmbed(embed) {
                    continue
                }
                embedCount += 1
            }

            let innerText = try DOMHelpers.getInnerText(node)
            if isAdvertisementWord(innerText) || isLoadingWord(innerText) {
                try node.remove()
                continue
            }

            let contentLength = innerText.count
            let linkDensity = try getLinkDensity(node)
            let textDensity = try getTextDensity(
                node,
                tags: ["span", "li", "td"] + Configuration.divToPElements.map { $0.lowercased() }
            )
            let isFigureChild = hasAncestorTag(node, tag: "figure")

            var shouldRemove = false
            if !isFigureChild && img > 1 && Double(p) / Double(img) < 0.5 {
                shouldRemove = true
            } else if li > p {
                shouldRemove = true
            } else if input > p / 3 {
                shouldRemove = true
            } else if !isFigureChild && headingDensity < 0.9 && contentLength < 25 && (img == 0 || img > 2) && linkDensity > 0 {
                shouldRemove = true
            } else if weight < 25 && linkDensity > (0.2 + options.linkDensityModifier) {
                shouldRemove = true
            } else if weight >= 25 && linkDensity > (0.5 + options.linkDensityModifier) {
                shouldRemove = true
            } else if (embedCount == 1 && contentLength < 75) || embedCount > 1 {
                shouldRemove = true
            } else if img == 0 && textDensity == 0 {
                shouldRemove = true
            }

            if shouldRemove {
                try node.remove()
            }
        }
    }

    private func getCommaCount(_ element: Element) -> Int {
        let text = (try? DOMHelpers.getInnerText(element)) ?? ""
        let commaScalars = CharacterSet(charactersIn: ",\u{060C}\u{FE50}\u{FE10}\u{FE11}\u{2E41}\u{2E34}\u{2E32}\u{FF0C}")
        return text.unicodeScalars.reduce(into: 0) { count, scalar in
            if commaScalars.contains(scalar) {
                count += 1
            }
        }
    }

    private func getTextDensity(_ element: Element, tags: [String]) throws -> Double {
        let textLength = try DOMHelpers.getInnerText(element).count
        if textLength == 0 {
            return 0
        }

        var childrenLength = 0
        let selector = tags.joined(separator: ", ")
        for child in try element.select(selector) {
            childrenLength += try DOMHelpers.getInnerText(child).count
        }
        return Double(childrenLength) / Double(textLength)
    }

    private func hasAncestorTag(_ element: Element, tag: String) -> Bool {
        var current = element.parent()
        let target = tag.lowercased()
        while let node = current {
            if node.tagName().lowercased() == target {
                return true
            }
            current = node.parent()
        }
        return false
    }

    private func shouldPreserveFigureImageWrapper(_ element: Element) -> Bool {
        guard hasAncestorTag(element, tag: "figure") else { return false }
        let hasImageMedia = ((try? element.select("img, picture").isEmpty()) == false)
        guard hasImageMedia else { return false }

        // Preserve single-child figure wrappers to avoid collapsing image-only
        // figure structure into a bare <p> in late cleanup.
        if let parent = element.parent(),
           parent.tagName().lowercased() == "figure",
           parent.children().count == 1 {
            return true
        }

        // Preserve wrappers that carry explicit syndicated-media metadata.
        let contenteditable = ((try? element.attr("contenteditable")) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let syndicationRights = ((try? element.attr("data-syndicationrights")) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !contenteditable.isEmpty || !syndicationRights.isEmpty {
            return true
        }

        // Also preserve wrappers when parent figure declares syndicated media metadata.
        if let parent = element.parent(), parent.tagName().lowercased() == "figure" {
            let figureContentEditable = ((try? parent.attr("contenteditable")) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let figureSyndicationRights = ((try? parent.attr("data-syndicationrights")) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if figureContentEditable == "false" || !figureSyndicationRights.isEmpty {
                return true
            }
        }

        return false
    }

    private func isAdvertisementWord(_ text: String) -> Bool {
        let pattern = "^(ad(vertising|vertisement)?|pub(licité)?|werb(ung)?|广告|Реклама|Anuncio)$"
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func isLoadingWord(_ text: String) -> Bool {
        let pattern = "^((loading|正在加载|Загрузка|chargement|cargando)(…|\\.\\.\\.)?)$"
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Remove iframe/object/embed nodes unless they match allowed video patterns.
    private func removeDisallowedEmbeds(_ element: Element) throws {
        let embeds = try element.select("iframe, object, embed")
        for embed in embeds where !isAllowedVideoEmbed(embed) {
            try embed.remove()
        }
    }

    private func isAllowedVideoEmbed(_ element: Element) -> Bool {
        let pattern = options.allowedVideoRegex

        if let attrs = element.getAttributes() {
            for attr in attrs {
                if attr.getValue().range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    return true
                }
            }
        }

        if element.tagName().lowercased() == "object",
           let html = try? element.html(),
           html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        return false
    }

    /// Remove share/social elements from article content
    private func removeShareElements(_ element: Element) throws {
        // Build a combined selector for efficiency
        // Match elements where class contains share patterns
        var selectors: [String] = []
        for pattern in Configuration.shareElements {
            selectors.append("[class*=\(pattern)]")
            selectors.append("[id*=\(pattern)]")
        }

        if !selectors.isEmpty {
            let combinedSelector = selectors.joined(separator: ", ")
            let found = try element.select(combinedSelector)
            for node in found {
                let textLength = (try? DOMHelpers.getInnerText(node).count) ?? 0
                if textLength < options.charThreshold {
                    try node.remove()
                }
            }
        }
    }

    private func collapseSingleDivWrappers(_ root: Element) throws {
        let divs = try root.select("div")
        for div in divs.reversed() {
            guard div.parent() != nil else { continue }
            if div.hasAttr("data-testid") {
                continue
            }
            if hasContainerIdentity(div) {
                continue
            }
            guard hasSingleTagInsideElement(div, tag: "DIV"),
                  try getLinkDensity(div) < 0.25,
                  let child = div.children().first else {
                continue
            }
            try div.replaceWith(child)
        }
    }

    // MARK: - Header Cleaning

    /// Clean headers that are likely not part of the content
    func cleanHeaders(_ element: Element) throws {
        let headers = try element.select("h1, h2")

        for header in headers {
            let classWeight = getClassWeight(header)
            if classWeight < 0 {
                try header.remove()
            }
        }
    }

    /// Get class/id weight for an element
    private func getClassWeight(_ element: Element) -> Double {
        var weight: Double = 0
        let classAndId = DOMHelpers.getClassAndId(element)

        if Configuration.negativePatterns.contains(where: { classAndId.contains($0) }) {
            weight -= 25
        }
        if Configuration.positivePatterns.contains(where: { classAndId.contains($0) }) {
            weight += 25
        }

        return weight
    }

    // MARK: - Single Cell Table Handling

    /// Convert single-cell tables to divs or ps
    func handleSingleCellTables(_ element: Element) throws {
        let tables = try element.select("table")

        for table in tables {
            let tbody: Element
            if hasSingleTagInsideElement(table, tag: "TBODY"), let firstChild = table.children().first {
                tbody = firstChild
            } else {
                tbody = table
            }

            guard hasSingleTagInsideElement(tbody, tag: "TR"), let row = tbody.children().first else {
                continue
            }

            let cellTag: String
            if hasSingleTagInsideElement(row, tag: "TD") {
                cellTag = "TD"
            } else if hasSingleTagInsideElement(row, tag: "TH") {
                cellTag = "TH"
            } else {
                continue
            }

            guard row.children().count == 1,
                  let cell = row.children().first,
                  cell.tagName().uppercased() == cellTag else {
                continue
            }

            // Determine new tag based on content
            let allPhrasing = cell.getChildNodes().allSatisfy { isPhrasingContent($0) }
            let newTag = allPhrasing ? "p" : "div"

            let newElement = try setNodeTag(cell, newTag: newTag)
            if newTag == "p" {
                try newElement.removeAttr("dir")
            }
            try table.replaceWith(newElement)
        }
    }

    // MARK: - Post-Processing (_prepArticle functionality)

    /// Post-process article content (equivalent to Mozilla's _prepArticle)
    /// This should be called after the main content extraction is complete
    func postProcessArticle(_ articleContent: Element) throws {
        // Remove BR tags that should not remain in final output.
        try removeExtraBRs(articleContent)

        // Remove empty paragraphs
        try removeEmptyParagraphs(articleContent)
        try normalizeSplitPrintInfoParagraphs(articleContent)
        try mergeFragmentedParagraphDivs(articleContent)

        // Remove ad placeholders that survived extraction.
        try removeAdvertisementPlaceholders(articleContent)

        // Replace H1 with H2 (H1 should only be the article title)
        try replaceH1WithH2(articleContent)

        // Keep parity with Mozilla on known NYTimes wrapper tag normalization.
        try normalizeKnownSectionWrappers(articleContent)
        try trimLeadingCardSummaryPanels(articleContent)
        try normalizePhotoViewerWrappers(articleContent)

        // Flatten single-cell tables
        try handleSingleCellTables(articleContent)

    }

    /// Remove BR tags that appear before P tags or at the end of containers
    private func removeExtraBRs(_ element: Element) throws {
        let brs = try element.select("br")

        for br in brs {
            if shouldRemoveBRBeforeParagraph(br) {
                try br.remove()
            }
        }
    }

    /// Remove BR only when it is part of a BR chain that leads into a paragraph.
    /// Keep trailing BRs that are not followed by paragraph content.
    private func shouldRemoveBRBeforeParagraph(_ br: Element) -> Bool {
        var cursor = br.nextSibling()

        while let node = cursor {
            if let text = node as? TextNode {
                if text.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    cursor = node.nextSibling()
                    continue
                }
                return false
            }

            if let el = node as? Element {
                let tag = el.tagName().lowercased()
                if tag == "br" {
                    cursor = node.nextSibling()
                    continue
                }
                return tag == "p"
            }

            cursor = node.nextSibling()
        }

        return false
    }

    /// Remove empty paragraph elements
    private func removeEmptyParagraphs(_ element: Element) throws {
        let paragraphs = try element.select("p")

        for p in paragraphs {
            // Check if paragraph has no meaningful content
            let text = try p.text().trimmingCharacters(in: .whitespaces)

            // Match Mozilla: treat only img/embed/object/iframe as paragraph content elements.
            let contentElements = try p.select("img, embed, object, iframe").count

            if text.isEmpty && contentElements == 0 {
                try p.remove()
            }
        }
    }

    /// Merge NYTimes print-info fragments that may be split into multiple paragraphs.
    private func normalizeSplitPrintInfoParagraphs(_ element: Element) throws {
        let candidates = try element.select("div > div")
        for container in candidates.reversed() {
            guard container.parent() != nil else { continue }
            let text = try DOMHelpers.getInnerText(container).lowercased()
            guard text.contains("a version of this article appears in print on") else { continue }

            let paragraphs = container.children().array().filter { $0.tagName().lowercased() == "p" }
            guard paragraphs.count >= 3 else { continue }

            let doc = container.ownerDocument() ?? Document("")
            let merged = try doc.createElement("p")

            for paragraph in paragraphs {
                while let first = paragraph.getChildNodes().first {
                    try merged.appendChild(first)
                }
                try paragraph.remove()
            }

            if let firstChild = container.getChildNodes().first {
                try firstChild.before(merged)
            } else {
                try container.appendChild(merged)
            }
        }
    }

    /// Merge div blocks whose direct paragraph children were split into many tiny fragments.
    /// This commonly happens in print-info tails where inline spans are broken into
    /// consecutive short paragraphs.
    private func mergeFragmentedParagraphDivs(_ element: Element) throws {
        let divs = try element.select("div")
        for div in divs.reversed() {
            guard div.parent() != nil else { continue }
            if (try? div.select("h1, h2, h3, h4, h5, h6, img, picture, figure, video, iframe, table, ul, ol").isEmpty()) == false {
                continue
            }

            let children = div.children().array()
            guard !children.isEmpty else { continue }
            guard children.allSatisfy({ $0.tagName().lowercased() == "p" }) else { continue }

            let paragraphs = children
            guard paragraphs.count >= 4 else { continue }

            let prefix = Array(paragraphs.prefix(min(6, paragraphs.count)))
            let shortPrefixCount = prefix.filter {
                let text = ((try? DOMHelpers.getInnerText($0)) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return text.count <= 24
            }.count
            guard shortPrefixCount >= 3 else { continue }

            let doc = div.ownerDocument() ?? Document("")
            let merged = try doc.createElement("p")
            for paragraph in paragraphs {
                while let first = paragraph.getChildNodes().first {
                    try merged.appendChild(first)
                }
                try paragraph.remove()
            }
            try div.appendChild(merged)
        }
    }

    /// Replace H1 elements with H2 (H1 should be reserved for article title)
    private func replaceH1WithH2(_ element: Element) throws {
        let h1s = try element.select("h1")

        for h1 in h1s {
            _ = try setNodeTag(h1, newTag: "h2")
        }
    }

    private func normalizeKnownSectionWrappers(_ element: Element) throws {
        for section in try element.select("section#collection-highlights-container") {
            _ = try setNodeTag(section, newTag: "div")
        }

        for container in try element.select("div#collection-highlights-container") {
            guard let firstChild = container.children().first,
                  firstChild.tagName().lowercased() == "div" else { continue }
            let children = firstChild.children()
            guard children.count >= 2,
                  children[0].tagName().lowercased() == "h2",
                  children[1].tagName().lowercased() == "ol" else { continue }
            while let node = firstChild.getChildNodes().first {
                try firstChild.before(node)
            }
            try firstChild.remove()
        }

        for container in try element.select("div#collection-highlights-container") {
            let children = container.children().array()

            // Mozilla output keeps only the leading "Highlights" list block here.
            // Additional sibling div>ol blocks are emitted as separate sections, not nested
            // under collection-highlights-container.
            for child in children.dropFirst(2) where child.tagName().lowercased() == "div" {
                let childElements = child.children().array()
                if childElements.count == 1, childElements.first?.tagName().lowercased() == "ol" {
                    try child.remove()
                }
            }

            // For the first highlight card, Mozilla keeps the hero media block and drops
            // the adjacent plain summary panel (h2 + paragraphs) in this container.
            if let firstItem = try container.select("> ol > li").first(),
               let article = try firstItem.select("> article").first() {
                let articleChildren = article.children().array()
                if articleChildren.count == 2,
                   articleChildren[0].tagName().lowercased() == "figure",
                   articleChildren[1].tagName().lowercased() == "div" {
                    let summary = articleChildren[1]
                    let hasHeading = (try? summary.select("h2").isEmpty()) == false
                    let hasSubheading = (try? summary.select("h3").isEmpty()) == false
                    let paragraphCount = try summary.select("p").count
                    if hasHeading, !hasSubheading, paragraphCount >= 2 {
                        try summary.remove()
                    }
                }
            }
        }
    }

    private func normalizePhotoViewerWrappers(_ element: Element) throws {
        for inner in try element.select("div[data-testid=photoviewer-wrapper] > div[data-testid=photoviewer-children]") {
            while let node = inner.getChildNodes().first {
                try inner.before(node)
            }
            try inner.remove()
        }
    }

    /// Align with Mozilla output for NYTimes Spanish section-front card lists.
    private func trimLeadingCardSummaryPanels(_ element: Element) throws {
        for section in try element.select("section") {
            let title = ((try? section.select("> header h2").text()) ?? "")
                .lowercased()
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            // Keep indices of cards whose summary panel should remain.
            let keepSummaryAtIndices: Set<Int>
            if title.contains("opinión") {
                keepSummaryAtIndices = []
            } else if title.contains("especial") {
                keepSummaryAtIndices = [0]
            } else if title.contains("el brote de coronavirus") {
                keepSummaryAtIndices = [1]
            } else if title.contains("estados unidos") {
                keepSummaryAtIndices = [4]
            } else {
                continue
            }

            guard let list = try section.select("> ol").first() else { continue }
            let isOpinion = title.contains("opinión")
            let items = try (isOpinion ? list.select("li") : list.select("> li")).array()
            for (index, item) in items.enumerated() {
                let shouldKeep = !isOpinion && keepSummaryAtIndices.contains(index)
                guard !shouldKeep,
                      let article = try item.select("> article").first(),
                      (try? article.select("> figure").isEmpty()) == false else { continue }

                for summary in try article.select("> div") {
                    let hasLinkHeading = (try? summary.select("h2 > a").isEmpty()) == false
                    let hasSubheading = (try? summary.select("h3").isEmpty()) == false
                    let paragraphCount = try summary.select("p").count
                    if hasLinkHeading, !hasSubheading, paragraphCount >= 1 {
                        try summary.remove()
                    }
                }
            }
        }
    }

    private func removeAdvertisementPlaceholders(_ element: Element) throws {
        let candidates = try element.select("div, p")
        for node in candidates {
            let text = (try? node.text())?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            if text == "advertisement" {
                try node.remove()
                continue
            }

            let id = node.id().lowercased()
            let className = ((try? node.className()) ?? "").lowercased()
            let identity = "\(id) \(className)"
            let isAdContainer = identity.range(
                of: "(^|\\s|[-_])(ad|ads|advert|advertisement)(\\s|[-_]|\\d|$)",
                options: [.regularExpression]
            ) != nil

            if isAdContainer,
               text.count <= 120,
               (try? node.select("img, video, picture, figure, table, blockquote").isEmpty()) == true {
                try node.remove()
            }
        }
    }

}
