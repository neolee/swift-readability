import Foundation

/// Errors that can occur during Readability parsing
public enum ReadabilityError: Error, CustomStringConvertible, Sendable {
    /// Could not find article content in the document
    case noContent

    /// Extracted content is below the minimum character threshold
    case contentTooShort(actualLength: Int, threshold: Int)

    /// HTML parsing failed
    case parsingFailed(underlying: Error)

    /// Invalid HTML input
    case invalidHTML

    /// A required element was not found
    case elementNotFound(String)

    public var description: String {
        switch self {
        case .noContent:
            return "Could not find article content in the document"
        case .contentTooShort(let actual, let threshold):
            return "Extracted content is too short (\(actual) characters, minimum \(threshold))"
        case .parsingFailed(let error):
            return "HTML parsing failed: \(error.localizedDescription)"
        case .invalidHTML:
            return "Invalid HTML input"
        case .elementNotFound(let selector):
            return "Required element not found: \(selector)"
        }
    }
}
