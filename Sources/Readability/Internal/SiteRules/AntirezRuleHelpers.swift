import Foundation
import SwiftSoup

enum AntirezRuleHelpers {
    static func isAntirezDocument(_ document: Document, sourceURL: URL?) -> Bool {
        let host = sourceURL?.host?.lowercased() ?? ""
        if host == "antirez.com" || host.hasSuffix(".antirez.com") {
            return true
        }

        let title = ((try? document.title()) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if title.hasSuffix("- <antirez>") {
            return true
        }

        let headerTitle = ((try? document.select("header h1 > a[href='/']").first()?.text()) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return headerTitle == "<antirez>"
    }

    static func metadataInfoNode(in document: Document) throws -> Element? {
        for info in try document.select("span.info") {
            if try isArticleMetadataInfoNode(info) {
                return info
            }
        }
        return nil
    }

    static func extractedAuthor(in document: Document) throws -> String? {
        guard let info = try metadataInfoNode(in: document) else {
            return nil
        }

        let selectors = [
            "span.username > a[href^='/user/']",
            "a[href^='/user/']",
            "span.username"
        ]

        for selector in selectors {
            if let node = try info.select(selector).first() {
                let text = try node.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    return text
                }
            }
        }

        return nil
    }

    static func isArticleMetadataInfoNode(_ node: Element) throws -> Bool {
        guard node.tagName().lowercased() == "span" else { return false }

        guard let article = node.parent(), article.tagName().lowercased() == "article" else {
            return false
        }

        let articleChildren = article.children().array()
        guard articleChildren.first === node else { return false }

        let hasBodyPre = articleChildren.contains { child in
            child.tagName().lowercased() == "pre"
        }
        guard hasBodyPre else { return false }

        let hasAuthorLink = (try? node.select("span.username > a[href^='/user/'], a[href^='/user/']").isEmpty()) == false
        guard hasAuthorLink else { return false }

        let classTokens = ((try? node.className()) ?? "")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        if classTokens.contains("info") {
            return true
        }

        let text = (try? node.text())?.lowercased() ?? ""
        return text.contains("views.")
    }

    static func candidateArticleNodes(in root: Element) -> [Element] {
        var articles: [Element] = []

        if root.tagName().lowercased() == "article",
           root.hasAttr("data-comment-id"),
           root.hasAttr("id") {
            articles.append(root)
        }

        if let nested = try? root.select("article[data-comment-id][id]").array() {
            for article in nested where !articles.contains(where: { $0 === article }) {
                articles.append(article)
            }
        }

        return articles
    }
}