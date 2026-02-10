import Foundation
import Readability

enum CLIError: Error {
    case noInput
    case invalidURL
    case invalidHTML
    case invalidArguments(String)
    case benchmarkInputListRequired
}

extension CLIError: CustomStringConvertible {
    var description: String {
        switch self {
        case .noInput:
            return "No input provided. Use: readability-cli <url>, pipe HTML via stdin, or --benchmark."
        case .invalidURL:
            return "Invalid URL provided."
        case .invalidHTML:
            return "Could not decode HTML."
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .benchmarkInputListRequired:
            return "Benchmark mode requires --benchmark-input-list <path>."
        }
    }
}

struct CLIOptions {
    var help = false
    var asJSON = false
    var textOnly = false
    var benchmark = false
    var benchmarkInputList: String?
    var benchmarkOutput: String?
    var benchmarkIterations = 5
    var benchmarkWarmup = 1
    var benchmarkHoldSeconds = 0
    var positional: [String] = []
}

struct BenchmarkCaseResult: Codable {
    let path: String
    let iterations: Int
    let warmup: Int
    let runsMs: [Double]
    let averageMs: Double
    let p50Ms: Double
    let p95Ms: Double
    let minMs: Double
    let maxMs: Double
}

struct BenchmarkReport: Codable {
    let generatedAt: String
    let swiftVersionHint: String
    let iterations: Int
    let warmup: Int
    let totalCases: Int
    let totalMeasuredRuns: Int
    let overallP50Ms: Double
    let overallP95Ms: Double
    let overallAverageMs: Double
    let throughputPagesPerSecond: Double
    let cases: [BenchmarkCaseResult]
}

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
    print(
        """
        Readability CLI - Extract readable content from HTML

        Usage:
            readability-cli <url>                     # Fetch and parse URL
            cat file.html | readability-cli           # Read from stdin
            readability-cli < file.html               # Read from stdin
            readability-cli --benchmark ...           # Run performance benchmark

        Options:
            --text-only                               Output plain text instead of HTML
            --json                                    Output as JSON
            --benchmark                               Run benchmark mode
            --benchmark-input-list <path>             File containing HTML paths (one per line)
            --benchmark-output <path>                 Benchmark JSON report output path
            --benchmark-iterations <N>                Measured iterations per case (default: 5)
            --benchmark-warmup <N>                    Warmup iterations per case (default: 1)
            --benchmark-hold-seconds <N>              Keep process alive after benchmark (default: 0)
            -h, --help                                Show this help message
        """
    )
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
        return
    }

    if textOnly {
        print("Title: \(result.title)")
        print("")
        if let excerpt = result.excerpt {
            print("Excerpt: \(excerpt)")
            print("")
        }
        print(result.textContent)
        return
    }

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

func printError(_ message: String) {
    if let data = (message + "\n").data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

func parseOptions(_ args: [String]) throws -> CLIOptions {
    var options = CLIOptions()
    var index = 0

    while index < args.count {
        let arg = args[index]
        switch arg {
        case "-h", "--help":
            options.help = true
        case "--json":
            options.asJSON = true
        case "--text-only":
            options.textOnly = true
        case "--benchmark":
            options.benchmark = true
        case "--benchmark-input-list":
            index += 1
            guard index < args.count else {
                throw CLIError.invalidArguments("missing value for --benchmark-input-list")
            }
            options.benchmarkInputList = args[index]
        case "--benchmark-output":
            index += 1
            guard index < args.count else {
                throw CLIError.invalidArguments("missing value for --benchmark-output")
            }
            options.benchmarkOutput = args[index]
        case "--benchmark-iterations":
            index += 1
            guard index < args.count, let value = Int(args[index]), value > 0 else {
                throw CLIError.invalidArguments("invalid value for --benchmark-iterations")
            }
            options.benchmarkIterations = value
        case "--benchmark-warmup":
            index += 1
            guard index < args.count, let value = Int(args[index]), value >= 0 else {
                throw CLIError.invalidArguments("invalid value for --benchmark-warmup")
            }
            options.benchmarkWarmup = value
        case "--benchmark-hold-seconds":
            index += 1
            guard index < args.count, let value = Int(args[index]), value >= 0 else {
                throw CLIError.invalidArguments("invalid value for --benchmark-hold-seconds")
            }
            options.benchmarkHoldSeconds = value
        default:
            if arg.hasPrefix("-") {
                throw CLIError.invalidArguments("unknown option \(arg)")
            }
            options.positional.append(arg)
        }
        index += 1
    }

    return options
}

func percentile(_ values: [Double], p: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    if sorted.count == 1 { return sorted[0] }
    let rank = max(0, min(Double(sorted.count - 1), p * Double(sorted.count - 1)))
    let lowerIndex = Int(rank.rounded(.down))
    let upperIndex = Int(rank.rounded(.up))
    if lowerIndex == upperIndex {
        return sorted[lowerIndex]
    }
    let fraction = rank - Double(lowerIndex)
    return sorted[lowerIndex] * (1.0 - fraction) + sorted[upperIndex] * fraction
}

func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

func resolveCasePath(_ entry: String, baseDirectory: URL) -> URL {
    if entry.hasPrefix("/") {
        return URL(fileURLWithPath: entry)
    }
    return baseDirectory.appendingPathComponent(entry)
}

func loadBenchmarkInputList(path: String) throws -> [String] {
    let content = try String(contentsOfFile: path, encoding: .utf8)
    return content
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

func runBenchmark(_ options: CLIOptions) throws {
    guard let listPath = options.benchmarkInputList else {
        throw CLIError.benchmarkInputListRequired
    }

    let caseEntries = try loadBenchmarkInputList(path: listPath)
    let listURL = URL(fileURLWithPath: listPath)
    let listBaseDirectory = listURL.deletingLastPathComponent()
    let baseURL = URL(string: "http://fakehost/test/index.html")
    var caseResults: [BenchmarkCaseResult] = []
    var allRunsMs: [Double] = []
    let wallStart = DispatchTime.now().uptimeNanoseconds

    for entry in caseEntries {
        let caseURL = resolveCasePath(entry, baseDirectory: listBaseDirectory)
        let html = try String(contentsOf: caseURL, encoding: .utf8)

        for _ in 0..<options.benchmarkWarmup {
            let readability = try Readability(html: html, baseURL: baseURL)
            _ = try readability.parse()
        }

        var runsMs: [Double] = []
        for _ in 0..<options.benchmarkIterations {
            let start = DispatchTime.now().uptimeNanoseconds
            let readability = try Readability(html: html, baseURL: baseURL)
            _ = try readability.parse()
            let elapsedNs = DispatchTime.now().uptimeNanoseconds - start
            let elapsedMs = Double(elapsedNs) / 1_000_000.0
            runsMs.append(elapsedMs)
            allRunsMs.append(elapsedMs)
        }

        guard let minMs = runsMs.min(), let maxMs = runsMs.max() else { continue }
        let caseResult = BenchmarkCaseResult(
            path: entry,
            iterations: options.benchmarkIterations,
            warmup: options.benchmarkWarmup,
            runsMs: runsMs,
            averageMs: average(runsMs),
            p50Ms: percentile(runsMs, p: 0.50),
            p95Ms: percentile(runsMs, p: 0.95),
            minMs: minMs,
            maxMs: maxMs
        )
        caseResults.append(caseResult)
        printError("bench case: \(entry) p50=\(String(format: "%.2f", caseResult.p50Ms))ms p95=\(String(format: "%.2f", caseResult.p95Ms))ms")
    }

    let wallElapsedNs = DispatchTime.now().uptimeNanoseconds - wallStart
    let wallElapsedSeconds = Double(wallElapsedNs) / 1_000_000_000.0
    let measuredRuns = caseResults.count * options.benchmarkIterations
    let throughput = wallElapsedSeconds > 0 ? Double(measuredRuns) / wallElapsedSeconds : 0

    let report = BenchmarkReport(
        generatedAt: ISO8601DateFormatter().string(from: Date()),
        swiftVersionHint: "swift-tools-version: 6.2",
        iterations: options.benchmarkIterations,
        warmup: options.benchmarkWarmup,
        totalCases: caseResults.count,
        totalMeasuredRuns: measuredRuns,
        overallP50Ms: percentile(allRunsMs, p: 0.50),
        overallP95Ms: percentile(allRunsMs, p: 0.95),
        overallAverageMs: average(allRunsMs),
        throughputPagesPerSecond: throughput,
        cases: caseResults
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(report)

    if let outputPath = options.benchmarkOutput {
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL)
        printError("benchmark report written: \(outputPath)")
    } else if let json = String(data: data, encoding: .utf8) {
        print(json)
    }

    if options.benchmarkHoldSeconds > 0 {
        printError("holding process for \(options.benchmarkHoldSeconds)s for profiler attach stability ...")
        Thread.sleep(forTimeInterval: TimeInterval(options.benchmarkHoldSeconds))
    }
}

@main
struct ReadabilityCLI {
    static func main() async {
        do {
            let rawArgs = Array(CommandLine.arguments.dropFirst())
            let options = try parseOptions(rawArgs)

            if options.help {
                printUsage()
                return
            }

            if options.benchmark {
                try runBenchmark(options)
                return
            }

            let html: String
            let baseURL: URL?

            if let urlString = options.positional.first {
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
            try outputResult(result, asJSON: options.asJSON, textOnly: options.textOnly)
        } catch {
            printError("Error: \(error)")
            if case CLIError.noInput = error {
                printUsage()
            }
            exit(1)
        }
    }
}
