import Foundation

public struct ReadabilityResult: Sendable {
    public let title: String
    public let byline: String?
    public let content: String
    public let textContent: String
    public let excerpt: String?
    public let length: Int

    public init(
        title: String,
        byline: String? = nil,
        content: String,
        textContent: String,
        excerpt: String? = nil
    ) {
        self.title = title
        self.byline = byline
        self.content = content
        self.textContent = textContent
        self.excerpt = excerpt
        self.length = textContent.count
    }
}
