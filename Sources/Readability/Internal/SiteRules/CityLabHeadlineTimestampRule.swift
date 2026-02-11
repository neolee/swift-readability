import Foundation
import SwiftSoup

/// Normalizes CityLab headline/timestamp block to Mozilla-compatible structure.
///
/// SiteRule Metadata:
/// - Scope: CityLab article header metadata block
/// - Phase: `postProcess` normalization
/// - Trigger: `p > h2[itemprop=headline]` with `meta[itemprop=datePublished]`
/// - Evidence: `realworld/citylab-1`
/// - Risk if misplaced: unnecessary wrapper insertion around generic headings
enum CityLabHeadlineTimestampRule: SerializationSiteRule {
    static let id = "citylab-headline-timestamp"

    static func apply(to articleContent: Element) throws {
        guard let datePublished = (try? articleContent.select("meta[itemprop=datePublished]").first()) ?? nil else {
            return
        }
        let rawPublished = (try? datePublished.attr("content")) ?? ""
        let formattedTime = formatCityLabTime(rawPublished)

        for wrapper in try articleContent.select("p").reversed() {
            let children = wrapper.children()
            guard children.count == 1,
                  let headline = children.first,
                  headline.tagName().lowercased() == "h2" else {
                continue
            }
            let itemprop = ((try? headline.attr("itemprop")) ?? "").lowercased()
            guard itemprop.contains("headline") else {
                continue
            }
            let doc = wrapper.ownerDocument() ?? Document("")
            let container = try doc.createElement("div")
            try container.appendChild(headline)

            if let formattedTime {
                let timeContainer = try doc.createElement("div")
                let p = try doc.createElement("p")
                let span = try doc.createElement("span")
                let time = try doc.createElement("time")
                try time.text(formattedTime)
                try span.appendChild(time)
                try p.appendChild(span)
                try timeContainer.appendChild(p)
                try container.appendChild(timeContainer)
            }

            try wrapper.replaceWith(container)
        }

        // Keep author bio block while dropping CityLab RSS feed lists.
        let lists = try articleContent.select("ul")
        for list in lists.reversed() {
            let links = try list.select("a")
            let hasAuthorFeedLink = links.contains { link in
                let href = ((try? link.attr("href")) ?? "").lowercased()
                return href.contains("/feeds/author/")
            }
            if hasAuthorFeedLink {
                try list.remove()
            }
        }
    }

    private static func formatCityLabTime(_ iso8601: String) -> String? {
        let pattern = "T(\\d{2}):(\\d{2}):\\d{2}([+-]\\d{2}:\\d{2}|Z)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: iso8601, range: NSRange(location: 0, length: iso8601.utf16.count)),
              let hourRange = Range(match.range(at: 1), in: iso8601),
              let minuteRange = Range(match.range(at: 2), in: iso8601),
              let tzRange = Range(match.range(at: 3), in: iso8601),
              let hour = Int(iso8601[hourRange]) else {
            return nil
        }

        let minute = String(iso8601[minuteRange])
        let tz = String(iso8601[tzRange])
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        let meridiem = hour >= 12 ? "PM" : "AM"

        let tzLabel: String
        switch tz {
        case "-04:00", "-05:00":
            tzLabel = "ET"
        case "-07:00", "-08:00":
            tzLabel = "PT"
        case "Z":
            tzLabel = "UTC"
        default:
            tzLabel = "UTC"
        }

        return "\(displayHour):\(minute) \(meridiem) \(tzLabel)"
    }
}
