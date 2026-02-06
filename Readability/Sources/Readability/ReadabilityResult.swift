import Foundation

public struct ReadabilityResult: Sendable {
    public let title: String
    public let byline: String?
    public let dir: String?
    public let lang: String?
    public let content: String
    public let textContent: String
    public let excerpt: String?
    public let length: Int
    public let siteName: String?
    public let publishedTime: String?

    public init(
        title: String,
        byline: String? = nil,
        dir: String? = nil,
        lang: String? = nil,
        content: String,
        textContent: String,
        excerpt: String? = nil,
        siteName: String? = nil,
        publishedTime: String? = nil
    ) {
        self.title = title
        self.byline = byline
        self.dir = dir
        self.lang = lang
        self.content = content
        self.textContent = textContent
        self.excerpt = excerpt
        self.length = textContent.count
        self.siteName = siteName
        self.publishedTime = publishedTime
    }
}
