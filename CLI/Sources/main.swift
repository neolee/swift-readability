// CLI/Sources/main.swift
// ReadabilityCLI v2 - Issue Capture & Ground Truth Calibration Pipeline
// See CLI/PLAN-v2.md for design rationale.

import ArgumentParser
import Foundation
import Readability
import SwiftSoup

private struct StagedCaseMetadata: Decodable {
    let url: String
    let fetchedAt: String?
}

// MARK: - Entry point

@main
struct ReadabilityCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Issue Capture & Ground Truth Calibration Pipeline.",
        subcommands: [Fetch.self, Parse.self, Review.self, Commit.self, Clean.self, Inspect.self]
    )
}

// MARK: - Helpers

/// Write a diagnostic line to stderr.
private func printErr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

/// Returns the `.staging/<caseName>/` URL relative to the current working directory.
private func stagingCaseDir(for caseName: String) -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".staging")
        .appendingPathComponent(caseName)
}

/// Returns the `.staging/` root URL relative to the current working directory.
private func stagingRootDir() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".staging")
}

private func loadStagedCaseURL(for caseName: String) -> URL? {
    let metaURL = stagingCaseDir(for: caseName).appendingPathComponent("meta.json")
    guard let data = try? Data(contentsOf: metaURL),
          let metadata = try? JSONDecoder().decode(StagedCaseMetadata.self, from: data) else {
        return nil
    }

    let trimmedURL = metadata.url.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedURL.isEmpty else { return nil }
    return URL(string: trimmedURL)
}

/// Detect Node.js on $PATH. The bridge script requires Node.js (CJS + jsdom).
/// Returns the executable path, or nil if not found.
private func detectJSRuntime() -> (path: String, isDeno: Bool)? {
    for (name, isDeno) in [("node", false)] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [name]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()
        guard (try? task.run()) != nil else { continue }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { continue }
        let raw = outPipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: raw, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
            return (path, isDeno)
        }
    }
    return nil
}

// MARK: - fetch

struct Fetch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Fetch HTML from a URL and create a new staging case."
    )

    @Argument(help: "The URL to fetch (http/https only).")
    var url: String

    @Option(name: .long, help: "Name for this case (alphanumeric, hyphens, underscores).")
    var name: String

    mutating func run() async throws {
        let fm = FileManager.default

        // URL security validation
        guard let parsedURL = URL(string: url),
              let scheme = parsedURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw ValidationError("URL must use http or https scheme.")
        }
        guard let host = parsedURL.host?.lowercased(), !host.isEmpty else {
            throw ValidationError("URL has no valid host.")
        }
        let blockedExact: Set<String> = ["localhost", "::1", "[::1]", "0.0.0.0"]
        if blockedExact.contains(host) {
            throw ValidationError("URL host '\(host)' is a reserved address.")
        }
        let blockedPrefixes = [
            "127.", "10.", "192.168.", "169.254.",
            "172.16.", "172.17.", "172.18.", "172.19.", "172.20.",
            "172.21.", "172.22.", "172.23.", "172.24.", "172.25.",
            "172.26.", "172.27.", "172.28.", "172.29.", "172.30.", "172.31.",
            "[fc", "[fd", "[fe8"
        ]
        for prefix in blockedPrefixes where host.hasPrefix(prefix) {
            throw ValidationError("URL resolves to a private or reserved address (\(host)).")
        }

        // Case name validation — prevent path traversal
        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard !name.isEmpty,
              name.unicodeScalars.allSatisfy({ validChars.contains($0) }),
              !name.hasPrefix(".") else {
            throw ValidationError("Case name must be non-empty and contain only alphanumerics, hyphens, or underscores.")
        }

        let dest = stagingCaseDir(for: name)
        guard !fm.fileExists(atPath: dest.path) else {
            throw ValidationError("Case '\(name)' already exists in .staging/. Run 'clean \(name)' to remove it first.")
        }
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)

        printErr("Fetching \(url) ...")
        var request = URLRequest(url: parsedURL)
        request.timeoutInterval = 30
        request.setValue("Mozilla/5.0 (compatible; ReadabilityCLI/2.0)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                try? fm.removeItem(at: dest)
                throw ValidationError("HTTP \(http.statusCode) from server.")
            }
            try data.write(to: dest.appendingPathComponent("source.html"))

            let meta: [String: String] = [
                "url": url,
                "fetchedAt": ISO8601DateFormatter().string(from: Date())
            ]
            let metaData = try JSONSerialization.data(withJSONObject: meta, options: .prettyPrinted)
            try metaData.write(to: dest.appendingPathComponent("meta.json"))

            print("Staged '\(name)':")
            print("  source.html  (\(data.count) bytes)")
            print("  meta.json")
            print("")
            print("Next:  swift run ReadabilityCLI parse \(name)")
        } catch let err as ValidationError {
            throw err
        } catch {
            try? fm.removeItem(at: dest)
            throw error
        }
    }
}

// MARK: - parse

struct Parse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Run Swift and Mozilla Readability on a staged case for comparison."
    )

    @Argument(help: "The case name to parse.")
    var caseName: String

    mutating func run() async throws {
        let fm = FileManager.default
        let dest = stagingCaseDir(for: caseName)
        let sourceFile = dest.appendingPathComponent("source.html")
        guard fm.fileExists(atPath: sourceFile.path) else {
            throw ValidationError("No staged case '\(caseName)'. Run 'fetch <url> --name \(caseName)' first.")
        }

        let html = try String(contentsOf: sourceFile, encoding: .utf8)
        let caseURL = loadStagedCaseURL(for: caseName)

        // Swift Readability
        printErr("Swift Readability ...")
        let result = try Readability(html: html, baseURL: caseURL).parse()
        try result.content.write(
            to: dest.appendingPathComponent("swift-out.html"),
            atomically: true, encoding: .utf8)

        var swiftMeta: [String: Any] = ["title": result.title, "length": result.length]
        if let v = result.byline  { swiftMeta["byline"]  = v }
        if let v = result.excerpt { swiftMeta["excerpt"] = v }
        let swiftMetaData = try JSONSerialization.data(withJSONObject: swiftMeta, options: .prettyPrinted)
        try swiftMetaData.write(to: dest.appendingPathComponent("swift-result.json"))

        print("  swift-out.html")
        print("  swift-result.json")

        // Mozilla Readability.js
        guard let runtime = detectJSRuntime() else {
            print("")
            printErr("Note: node not found on $PATH. Mozilla comparison skipped.")
            printErr("Install Node.js and re-run 'parse \(caseName)'.")
            printErr("(The bridge script uses CJS + jsdom and requires Node.js.)")
            print("Next:  swift run ReadabilityCLI commit \(caseName)")
            return
        }

        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let bridgePath = cwd.appendingPathComponent("scripts/mozilla-bridge.js")
        guard fm.fileExists(atPath: bridgePath.path) else {
            printErr("Warning: bridge script not found at \(bridgePath.path). Mozilla comparison skipped.")
            return
        }

        printErr("Mozilla Readability.js (\(runtime.isDeno ? "deno" : "node")) ...")
        let bridgeInput = [sourceFile.path] + (caseURL.map { [$0.absoluteString] } ?? [])
        let args: [String] = runtime.isDeno
            ? ["run", "--allow-read", bridgePath.path] + bridgeInput
            : [bridgePath.path] + bridgeInput

        let jsProcess = Process()
        jsProcess.executableURL = URL(fileURLWithPath: runtime.path)
        jsProcess.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        jsProcess.standardOutput = outPipe
        jsProcess.standardError = errPipe
        try jsProcess.run()
        jsProcess.waitUntilExit()

        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let bridgeMessage = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !bridgeMessage.isEmpty {
            printErr("JS bridge: \(bridgeMessage)")
        }

        if jsProcess.terminationStatus == 2 {
            for fileName in ["mozilla-out.html", "draft-expected-metadata.json"] {
                let fileURL = dest.appendingPathComponent(fileName)
                if fm.fileExists(atPath: fileURL.path) {
                    try fm.removeItem(at: fileURL)
                }
            }

            let nullResult: [String: Any] = [
                "readable": false,
                "error": bridgeMessage.isEmpty
                    ? "Readability.parse() returned null — page may not be readable"
                    : bridgeMessage,
            ]
            let nullResultData = try JSONSerialization.data(
                withJSONObject: nullResult,
                options: [.prettyPrinted, .sortedKeys]
            )
            try nullResultData.write(to: dest.appendingPathComponent("mozilla-result.json"))

            print("  mozilla-result.json  (Mozilla returned null)")
            print("")
            printErr("Note: Mozilla Readability.js returned null for this page. Swift output was still generated.")
            print("Next:  swift run ReadabilityCLI review \(caseName)")
            return
        }

        guard jsProcess.terminationStatus == 0 else {
            throw ValidationError("Mozilla bridge exited with status \(jsProcess.terminationStatus).")
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard var json = try JSONSerialization.jsonObject(with: outData) as? [String: Any] else {
            throw ValidationError("Could not parse JS bridge output as JSON.")
        }

        // Write mozilla-out.html (content only)
        let mozContent = json["content"] as? String ?? ""
        try mozContent.write(
            to: dest.appendingPathComponent("mozilla-out.html"),
            atomically: true, encoding: .utf8)

        // Write mozilla-result.json (full bridge output)
        try outData.write(to: dest.appendingPathComponent("mozilla-result.json"))

        // Write draft-expected-metadata.json (metadata fields only — no content)
        json.removeValue(forKey: "content")
        let draftMetaData = try JSONSerialization.data(
            withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try draftMetaData.write(to: dest.appendingPathComponent("draft-expected-metadata.json"))

        print("  mozilla-out.html")
        print("  mozilla-result.json")
        print("  draft-expected-metadata.json")
        print("")
        print("Review, then promote to expected.*:")
        print("  cp .staging/\(caseName)/mozilla-out.html .staging/\(caseName)/expected.html")
        print("  cp .staging/\(caseName)/draft-expected-metadata.json .staging/\(caseName)/expected-metadata.json")
        print("  (edit as needed)")
        print("  swift run ReadabilityCLI commit \(caseName)")
    }
}

// MARK: - review

struct Review: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate a side-by-side HTML report and open it in the browser."
    )

    @Argument(help: "The case name to review.")
    var caseName: String

    mutating func run() async throws {
        let fm = FileManager.default
        let src = stagingCaseDir(for: caseName)
        guard fm.fileExists(atPath: src.appendingPathComponent("swift-out.html").path) else {
            throw ValidationError("No parse results for '\(caseName)'. Run 'parse \(caseName)' first.")
        }

        func read(_ name: String) -> String? {
            try? String(contentsOf: src.appendingPathComponent(name), encoding: .utf8)
        }

        // Each column carries a flag indicating whether the content is already a full HTML document
        // (source.html) or an extracted fragment that needs wrapping.
        var columns: [(label: String, content: String, isFullDoc: Bool)] = []
        if let c = read("source.html")         { columns.append(("Source HTML", c, true)) }
        if let c = read("swift-out.html")      { columns.append(("Swift Readability", c, false)) }
        if let c = read("mozilla-out.html")    { columns.append(("Mozilla Readability.js", c, false)) }
        if let c = read("draft-expected.html") { columns.append(("Draft Expected", c, false)) }

        // Wrap an extracted body fragment into a minimal standalone document for iframe rendering.
        func wrapDoc(_ body: String) -> String {
            """
            <!DOCTYPE html><html><head><meta charset="UTF-8"><style>
            body{font-family:-apple-system,system-ui,sans-serif;line-height:1.7;
            padding:20px 24px;color:#1a1a1a;max-width:760px;margin:0 auto;}
            img{max-width:100%;height:auto;}
            figure{margin:1em 0;}figcaption{font-size:.85em;color:#666;}
            </style></head><body>\(body)</body></html>
            """
        }

        // HTML-escape a full document for use as a `srcdoc` attribute value.
        // Using srcdoc (rather than src=) guarantees cross-browser local file loading.
        func srcdocEscape(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "\"", with: "&quot;")
        }

        let colsHTML = columns.map { label, content, isFullDoc in
            let doc = isFullDoc ? content : wrapDoc(content)
            let encoded = srcdocEscape(doc)
            return """
                <div class="col">
                  <div class="col-label">\(label)</div>
                  <iframe srcdoc="\(encoded)"></iframe>
                </div>
                """
        }.joined(separator: "\n")

        let report = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width">
        <title>Review: \(caseName)</title>
        <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        html, body { height: 100%; }
        body {
          font-family: system-ui, sans-serif;
          background: #18181b;
          color: #e4e4e7;
          display: flex;
          flex-direction: column;
          height: 100vh;
          overflow: hidden;
        }
        header {
          padding: 8px 16px;
          background: #09090b;
          border-bottom: 1px solid #27272a;
          font-size: 13px;
          flex-shrink: 0;
        }
        header .dim { color: #52525b; }
        header strong { color: #f4f4f5; }
        .cols {
          display: flex;
          flex: 1;
          gap: 1px;
          background: #27272a;
          overflow: hidden;
        }
        .col {
          flex: 1;
          display: flex;
          flex-direction: column;
          background: #fff;
          min-width: 0;
        }
        .col-label {
          background: #27272a;
          color: #a1a1aa;
          font-size: 11px;
          font-weight: 600;
          text-transform: uppercase;
          letter-spacing: .06em;
          padding: 5px 12px;
          flex-shrink: 0;
        }
        iframe {
          flex: 1;
          border: none;
          width: 100%;
        }
        </style>
        </head>
        <body>
        <header><span class="dim">review /</span> <strong>\(caseName)</strong></header>
        <div class="cols">
        \(colsHTML)
        </div>
        </body>
        </html>
        """

        let reportURL = stagingRootDir().appendingPathComponent("report.html")
        try report.write(to: reportURL, atomically: true, encoding: .utf8)

        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = [reportURL.path]
        try open.run()
        open.waitUntilExit()

        print("Columns: \(columns.map(\.label).joined(separator: " | "))")
        print("Report:  \(reportURL.path)")
    }
}

// MARK: - commit

struct Commit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Promote a finalized staging case into the ex-pages test suite."
    )

    @Argument(help: "The case name to commit.")
    var caseName: String

    mutating func run() async throws {
        let fm = FileManager.default
        let src = stagingCaseDir(for: caseName)
        guard fm.fileExists(atPath: src.path) else {
            throw ValidationError("No staged case '\(caseName)'. Run 'fetch' and 'parse' first.")
        }

        let sourceFile   = src.appendingPathComponent("source.html")
        let expectedHTML = src.appendingPathComponent("expected.html")
        let expectedMeta = src.appendingPathComponent("expected-metadata.json")
        let draftHTML    = src.appendingPathComponent("draft-expected.html")

        // Helpful error when drafts have not been renamed
        if !fm.fileExists(atPath: expectedHTML.path), fm.fileExists(atPath: draftHTML.path) {
            printErr("Error: draft-expected.html found but expected.html is missing. Rename before committing:")
            printErr("  mv .staging/\(caseName)/draft-expected.html .staging/\(caseName)/expected.html")
            printErr("  mv .staging/\(caseName)/draft-expected-metadata.json .staging/\(caseName)/expected-metadata.json")
            throw ExitCode.failure
        }
        guard fm.fileExists(atPath: sourceFile.path) else {
            throw ValidationError("source.html is missing from staging.")
        }
        guard fm.fileExists(atPath: expectedHTML.path) else {
            throw ValidationError("expected.html not found. Copy mozilla-out.html and rename it expected.html.")
        }
        guard fm.fileExists(atPath: expectedMeta.path) else {
            throw ValidationError("expected-metadata.json not found. Copy draft-expected-metadata.json and rename it.")
        }

        // Destination: ../Tests/ReadabilityTests/Resources/ex-pages/<caseName>/
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        let destDir = cwd
            .deletingLastPathComponent()
            .appendingPathComponent("Tests/ReadabilityTests/Resources/ex-pages")
            .appendingPathComponent(caseName)
            .standardized

        if fm.fileExists(atPath: destDir.path) {
            print("Note: ex-pages/\(caseName) already exists — overwriting.")
        } else {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
        }

        for (fileName, from) in [
            ("source.html",            sourceFile),
            ("expected.html",          expectedHTML),
            ("expected-metadata.json", expectedMeta),
            ("meta.json",              src.appendingPathComponent("meta.json"))
        ] {
            guard fm.fileExists(atPath: from.path) else { continue }
            let to = destDir.appendingPathComponent(fileName)
            if fm.fileExists(atPath: to.path) { try fm.removeItem(at: to) }
            try fm.copyItem(at: from, to: to)
            print("  Copied \(fileName) → ex-pages/\(caseName)/")
        }

        // Generate UpperCamelCase function suffix from case name
        let funcName = caseName
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined()

        print("")
        print("Add to ExPagesCompatibilityTests.swift:")
        print("""
            @Test("\(caseName) - Title matches expected")
            func test\(funcName)Title() async throws {
                guard let testCase = TestLoader.loadTestCase(named: "\(caseName)", in: "ex-pages") else {
                    Issue.record("Failed to load test case '\(caseName)'")
                    return
                }
                let result = try Readability(html: testCase.sourceHTML, baseURL: testCase.sourceURL, options: defaultOptions).parse()
                #expect(result.title == testCase.expectedMetadata.title)
            }
            """)
        print("")
        print("Staging not removed. Run 'clean \(caseName)' when done.")
    }
}

// MARK: - inspect

struct Inspect: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show extraction trace for a staged case (score breakdown, promotion path, pass summary)."
    )

    @Argument(help: "The case name to inspect (must be staged with 'fetch' first).")
    var caseName: String

    @Option(
        name: .long,
        parsing: .upToNextOption,
        help: "CSS selector probe to run against source.html. Repeat to inspect multiple selectors."
    )
    var selector: [String] = []

    mutating func run() async throws {
        let fm = FileManager.default
        let caseDir = stagingCaseDir(for: caseName)
        let sourceFile = caseDir.appendingPathComponent("source.html")
        guard fm.fileExists(atPath: sourceFile.path) else {
            throw ValidationError("No staged source.html for case '\(caseName)'. Run 'fetch' first.")
        }
        let html = try String(contentsOf: sourceFile, encoding: .utf8)
        let readability = try Readability(html: html)
        let (result, report) = try readability.parseWithInspection()

        var output = formatReport(report)
        if !selector.isEmpty {
            let sourceDoc = try SwiftSoup.parse(html)
            output += "\n\n" + formatSelectorProbe(
                selectors: selector,
                sourceDoc: sourceDoc,
                report: report,
                result: result
            )
        }
        print(output)
    }

    private func formatReport(_ report: InspectionReport) -> String {
        var lines: [String] = []

        // --- Pass summary ---
        for pass in report.passes {
            let flagStr = pass.activeFlags.isEmpty ? "(none)" : pass.activeFlags.joined(separator: " | ")
            let flagColumn = "[\(flagStr)]"
            let outcome: String
            if pass.accepted {
                outcome = "content=\(pass.contentLength) chars \u{2265} threshold=\(pass.charThreshold) → accepted"
            } else {
                outcome = "content=\(pass.contentLength) chars < threshold=\(pass.charThreshold) → retry"
            }
            lines.append("Pass \(String(pass.passNumber).padding(toLength: 2, withPad: " ", startingAt: 0))  \(flagColumn.padding(toLength: 30, withPad: " ", startingAt: 0))  \(outcome)")
        }

        // --- Focus pass: last accepted, or last overall if all failed ---
        guard let focusPass = report.passes.last(where: { $0.accepted }) ?? report.passes.last else {
            lines.append("(no passes recorded)")
            return lines.joined(separator: "\n")
        }

        lines.append("")
        let focusFlagStr = focusPass.activeFlags.isEmpty ? "(none)" : focusPass.activeFlags.joined(separator: " | ")
        lines.append("Top candidates (Pass \(focusPass.passNumber), flags=\(focusFlagStr)):")

        let finalDescriptor = focusPass.finalCandidate?.descriptor
        let initialDescriptor = focusPass.initialWinner?.descriptor
        let promotionOccurred = finalDescriptor != nil && finalDescriptor != initialDescriptor

        for (idx, candidate) in focusPass.topCandidates.enumerated() {
            var annotation = ""
            if promotionOccurred {
                if candidate.descriptor == finalDescriptor {
                    annotation = "  \u{2190} selected via promotion"
                } else if candidate.descriptor == initialDescriptor {
                    annotation = "  \u{2190} top scorer"
                }
            } else if candidate.descriptor == finalDescriptor {
                annotation = "  \u{2190} selected"
            }
            lines.append(String(format: "  #%-2d  %@  depth=%d  score=%.3f%@",
                                idx + 1, candidate.descriptor as CVarArg, candidate.depth, candidate.score, annotation as CVarArg))
            lines.append("        path=\(candidate.path)")
            let weightNote: String
            if focusPass.activeFlags.contains("WEIGHT") {
                weightNote = String(format: "%.1f", candidate.classWeightTotal)
            } else {
                weightNote = "0 (WEIGHT flag off)"
            }
            lines.append(String(format: "        base=%.0f  classWeight=%@  children=%+.3f",
                                candidate.baseScore, weightNote as CVarArg, candidate.childrenScore))
        }

        // --- Promotion trace ---
        if !focusPass.promotionTrace.isEmpty {
            lines.append("")
            lines.append("Promotion trace:")
            for step in focusPass.promotionTrace {
                lines.append("  \(step.descriptor.padding(toLength: 45, withPad: " ", startingAt: 0))  score=\(String(format: "%7.3f", step.score))  \(step.action)")
                lines.append("    path=\(step.path)")
            }
        }

        if let context = focusPass.candidateContext {
            lines.append("")
            lines.append("Candidate context:")
            lines.append("  candidate: \(context.candidateDescriptor) @ \(context.candidatePath)")
            if let parentDescriptor = context.parentDescriptor,
               let parentPath = context.parentPath {
                lines.append("  parent:    \(parentDescriptor) @ \(parentPath)")
            }
            if !context.ancestorChain.isEmpty {
                lines.append("  ancestors:")
                for ancestor in context.ancestorChain.prefix(6) {
                    lines.append("    - \(ancestor)")
                }
            }
            if !context.siblingDescriptors.isEmpty {
                lines.append("  siblings:")
                for sibling in context.siblingDescriptors.prefix(12) {
                    lines.append("    - \(sibling)")
                }
            }
        }

        if !focusPass.siblingDecisions.isEmpty {
            lines.append("")
            lines.append("Sibling merge trace:")
            for decision in focusPass.siblingDecisions {
                let visibility = decision.visible ? "visible" : "hidden"
                let paddedDecision = decision.decision.padding(toLength: 7, withPad: " ", startingAt: 0)
                let scoreText = String(format: "%6.3f", decision.score)
                let bonusText = String(format: "%6.3f", decision.bonus)
                let thresholdText = String(format: "%6.3f", decision.threshold)
                var line = "  [\(paddedDecision)] \(decision.descriptor)"
                line += "  score=\(scoreText)"
                line += "  bonus=\(bonusText)"
                line += "  threshold=\(thresholdText)"
                line += "  \(visibility)  reason=\(decision.reason)"
                if let ruleID = decision.siteRuleDecisionID {
                    line += "  rule=\(ruleID)"
                }
                lines.append(line)
                lines.append("        path=\(decision.path)")
            }
        }

        if !focusPass.siteRuleDecisions.isEmpty {
            lines.append("")
            lines.append("Site rule trace:")
            for decision in focusPass.siteRuleDecisions {
                var line = "  [\(decision.phase)] \(decision.ruleID)  action=\(decision.action)  target=\(decision.targetDescriptor) @ \(decision.targetPath)"
                if let resultDescriptor = decision.resultDescriptor,
                   let resultPath = decision.resultPath {
                    line += "  →  \(resultDescriptor) @ \(resultPath)"
                } else if let resultDescriptor = decision.resultDescriptor {
                    line += "  →  \(resultDescriptor)"
                }
                line += "  reason=\(decision.reason)"
                lines.append(line)
            }
        }

        if let snapshot = focusPass.contentSnapshot {
            lines.append("")
            lines.append("Content snapshot:")
            lines.append("  selected: \(snapshot.selectedCandidateDescriptor) @ \(snapshot.selectedCandidatePath)")
            lines.append("  content-length: \(snapshot.contentLength)")
            lines.append("  article-child-count: \(snapshot.articleChildCount)")
            lines.append("  article-children: \(snapshot.articleChildDescriptors.joined(separator: ", "))")
            lines.append("  single-wrapper: \(snapshot.usesSingleWrapper ? "yes" : "no")")
            if let wrapperDescriptor = snapshot.wrapperDescriptor,
               let wrapperPath = snapshot.wrapperPath {
                lines.append("  wrapper: \(wrapperDescriptor) @ \(wrapperPath)")
            }
            if !snapshot.leadingBlocks.isEmpty {
                lines.append("  leading-blocks:")
                for block in snapshot.leadingBlocks {
                    var line = "    - \(block.descriptor) @ \(block.path)"
                    line += "  children=\(block.childCount)"
                    if !block.textPreview.isEmpty {
                        line += "  text=\"\(block.textPreview)\""
                    }
                    lines.append(line)
                }
            }
        }

        // --- Class weight reference (passes where WEIGHT was active) ---
        let weightPasses = report.passes.filter { $0.activeFlags.contains("WEIGHT") }
        if !weightPasses.isEmpty {
            lines.append("")
            for wPass in weightPasses {
                let wFlagStr = wPass.activeFlags.joined(separator: " | ")
                lines.append("Class weight reference (Pass \(wPass.passNumber), flags=\(wFlagStr)):")
                var emitted = false
                for candidate in wPass.topCandidates {
                    for comp in candidate.classWeightComponents {
                        let sign = comp.points >= 0 ? "+" : ""
                        let patterns = comp.matchedPatterns.joined(separator: ", ")
                        lines.append("  \(candidate.descriptor)  \(sign)\(Int(comp.points))  [\(comp.attribute)==\(comp.side)]: \(patterns)")
                        emitted = true
                    }
                }
                if !emitted {
                    lines.append("  (no class/id weight components matched)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func formatSelectorProbe(
        selectors: [String],
        sourceDoc: Document,
        report: InspectionReport,
        result: ReadabilityResult
    ) -> String {
        var lines: [String] = []
        lines.append("Selector probe:")

        guard let focusPass = report.passes.last(where: { $0.accepted }) ?? report.passes.last else {
            lines.append("  (no passes recorded)")
            return lines.joined(separator: "\n")
        }

        var candidateMap: [String: String] = [:]
        for candidate in focusPass.topCandidates {
            candidateMap[candidate.path] = candidate.descriptor
        }
        if let finalCandidate = focusPass.finalCandidate {
            candidateMap[finalCandidate.path] = finalCandidate.descriptor
        }

        let extractedContent = result.content

        for selector in selectors {
            lines.append("  selector: \(selector)")

            do {
                let matches = try sourceDoc.select(selector)
                if matches.isEmpty() {
                    lines.append("    matches: 0")
                    continue
                }

                lines.append("    matches: \(matches.count)")

                for (index, match) in matches.array().enumerated() {
                    let descriptor = conciseElementDescriptor(match)
                    let path = nodePath(match)
                    let parentSummary: String
                    if let parent = match.parent() {
                        parentSummary = "\(conciseElementDescriptor(parent)) @ \(nodePath(parent))"
                    } else {
                        parentSummary = "(none)"
                    }

                    let nearestCandidate = nearestCandidateAncestor(for: match, candidateMap: candidateMap)
                    let nearestCandidateSummary = nearestCandidate.map { "\($0.descriptor) @ \($0.path)" } ?? "(none)"
                    let exactFragmentMatch = exactFragmentMatchInExtractedContent(match, extractedContent: extractedContent)

                    lines.append("    [\(index + 1)] \(descriptor) @ \(path)")
                    lines.append("         parent: \(parentSummary)")
                    lines.append("         nearest-candidate: \(nearestCandidateSummary)")
                    lines.append("         exact-fragment-match: \(exactFragmentMatch ? "yes" : "no")")
                }
            } catch {
                lines.append("    error: \(error)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func nearestCandidateAncestor(
        for element: Element,
        candidateMap: [String: String]
    ) -> (descriptor: String, path: String)? {
        var current: Element? = element
        while let node = current {
            let path = nodePath(node)
            if let descriptor = candidateMap[path] {
                return (descriptor: descriptor, path: path)
            }
            current = node.parent()
        }
        return nil
    }

    private func exactFragmentMatchInExtractedContent(_ element: Element, extractedContent: String) -> Bool {
        guard let html = try? element.outerHtml(), !html.isEmpty else {
            return false
        }
        return extractedContent.contains(html)
    }

    private func conciseElementDescriptor(_ element: Element) -> String {
        let tag = element.tagName().lowercased()
        let id = element.id()
        let firstClass = ((try? element.className()) ?? "")
            .split(separator: " ").first.map(String.init) ?? ""
        var desc = tag
        if !id.isEmpty {
            desc += "#\(id)"
        } else if !firstClass.isEmpty {
            desc += ".\(firstClass)"
        }
        return desc
    }

    private func nodePath(_ node: Node) -> String {
        var parts: [String] = []
        var current: Node? = node

        while let n = current {
            if let element = n as? Element {
                let tag = element.tagName().lowercased()
                var position = 1
                if let parent = element.parent() {
                    for sibling in parent.getChildNodes() {
                        guard sibling !== element else { break }
                        if let siblingElement = sibling as? Element,
                           siblingElement.tagName().lowercased() == tag {
                            position += 1
                        }
                    }
                }
                parts.append("\(tag)[\(position)]")
            } else if n is TextNode {
                parts.append("text()")
            } else {
                parts.append(n.nodeName())
            }
            current = n.parent()
        }

        return "/" + parts.reversed().joined(separator: "/")
    }
}

// MARK: - clean

struct Clean: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove staging files for a case or the entire .staging/ directory."
    )

    @Argument(help: "The case name to remove. Omit to clean the entire .staging/ directory.")
    var caseName: String?

    mutating func run() async throws {
        let fm = FileManager.default
        let root = stagingRootDir()

        if let name = caseName {
            let target = root.appendingPathComponent(name)
            guard fm.fileExists(atPath: target.path) else {
                throw ValidationError("No staged case '\(name)' found.")
            }
            print("About to delete: .staging/\(name)/  Confirm? [y/N] ", terminator: "")
            let response = (readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard response == "y" || response == "yes" else { print("Cancelled."); return }
            try fm.removeItem(at: target)
            print("Deleted .staging/\(name)/")
        } else {
            guard fm.fileExists(atPath: root.path) else {
                print("Nothing to clean: .staging/ does not exist.")
                return
            }
            print("About to delete: entire .staging/ directory.  Confirm? [y/N] ", terminator: "")
            let response = (readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard response == "y" || response == "yes" else { print("Cancelled."); return }
            try fm.removeItem(at: root)
            print("Deleted .staging/")
        }
    }
}

