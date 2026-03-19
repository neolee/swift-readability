// CLI/Sources/main.swift
// ReadabilityCLI v2 - Issue Capture & Ground Truth Calibration Pipeline
// See CLI/PLAN-v2.md for design rationale.

import ArgumentParser
import Foundation
import Readability

// MARK: - Entry point

@main
struct ReadabilityCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Issue Capture & Ground Truth Calibration Pipeline.",
        subcommands: [Fetch.self, Parse.self, Review.self, Commit.self, Clean.self]
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

        // Swift Readability
        printErr("Swift Readability ...")
        let result = try Readability(html: html).parse()
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
        let args: [String] = runtime.isDeno
            ? ["run", "--allow-read", bridgePath.path, sourceFile.path]
            : [bridgePath.path, sourceFile.path]

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
        if !errData.isEmpty,
           let msg = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !msg.isEmpty {
            printErr("JS bridge: \(msg)")
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
            ("expected-metadata.json", expectedMeta)
        ] {
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
                let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
                #expect(result.title == testCase.expectedMetadata.title)
            }
            """)
        print("")
        print("Staging not removed. Run 'clean \(caseName)' when done.")
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

