import Foundation
import Readability

// MARK: - CLI Error Handling

enum CLIError: Error {
    case noInput
    case invalidURL
    case invalidHTML
}

extension CLIError: CustomStringConvertible {
    var description: String {
        switch self {
        case .noInput:
            return "No input provided. Use: readability-cli <url> or pipe HTML via stdin"
        case .invalidURL:
            return "Invalid URL provided"
        case .invalidHTML:
            return "Could not parse HTML"
        }
    }
}

// MARK: - CLI Functions

func fetchHTML(from urlString: String) async throws -> String {
    guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else {
        throw CLIError.invalidURL
    }

    let (data, _) = try await URLSession.shared.data(from: url)

    guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
        throw CLIError.invalidHTML
    }

    return html
}

func readStdin() -> String? {
    var input = ""
    while let line = readLine(strippingNewline: false) {
        input += line
    }
    return input.isEmpty ? nil : input
}

func printUsage() {
    print("""
    Readability CLI - Extract readable content from HTML

    Usage:
        readability-cli <url>              # Fetch and parse URL
        cat file.html | readability-cli    # Read from stdin
        readability-cli < file.html        # Read from stdin

    Options:
        --text-only    Output plain text instead of HTML
        --json         Output as JSON
        -h, --help     Show this help message
    """)
}

func outputResult(_ result: ReadabilityResult, asJSON: Bool, textOnly: Bool) throws {
    if asJSON {
        let dict: [String: Any] = [
            "title": result.title,
            "content": result.content,
            "textContent": result.textContent,
            "excerpt": result.excerpt ?? NSNull(),
            "length": result.length
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    } else if textOnly {
        print("Title: \(result.title)")
        print("")
        if let excerpt = result.excerpt {
            print("Excerpt: \(excerpt)")
            print("")
        }
        print(result.textContent)
    } else {
        print("<html>")
        print("<head>")
        print("<meta charset=\"UTF-8\">")
        print("<title>\(result.title)</title>")
        print("</head>")
        print("<body>")
        print(result.content)
        print("</body>")
        print("</html>")
    }
}

func printError(_ message: String) {
    if let data = (message + "\n").data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

// MARK: - Main Entry Point

@main
struct ReadabilityCLI {
    static func main() async {
        let arguments = CommandLine.arguments.dropFirst()

        if arguments.contains("-h") || arguments.contains("--help") {
            printUsage()
            return
        }

        let asJSON = arguments.contains("--json")
        let textOnly = arguments.contains("--text-only")
        let positionalArgs = arguments.filter { !$0.hasPrefix("-") }

        do {
            let html: String
            let baseURL: URL?

            if let urlString = positionalArgs.first {
                printError("Fetching: \(urlString)...")
                html = try await fetchHTML(from: urlString)
                baseURL = URL(string: urlString)
                printError("Parsing content...")
            } else {
                guard let stdinHTML = readStdin() else {
                    throw CLIError.noInput
                }
                html = stdinHTML
                baseURL = nil
            }

            let readability = try Readability(html: html, baseURL: baseURL)
            let result = try readability.parse()

            try outputResult(result, asJSON: asJSON, textOnly: textOnly)

        } catch {
            printError("Error: \(error)")
            if case CLIError.noInput = error {
                printUsage()
            }
            exit(1)
        }
    }
}
