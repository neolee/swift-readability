import Foundation

#if canImport(os.signpost)
import os.signpost
#endif

enum PerfTrace {
    private static let enabled = ProcessInfo.processInfo.environment["READABILITY_SIGNPOSTS"] == "1"

    #if canImport(os.signpost)
    private static let log = OSLog(subsystem: "Readability", category: .pointsOfInterest)
    #endif

    @inline(__always)
    static func measure<T>(_ name: StaticString, _ block: () throws -> T) rethrows -> T {
        guard enabled else {
            return try block()
        }

        #if canImport(os.signpost)
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        defer { os_signpost(.end, log: log, name: name, signpostID: signpostID) }
        #endif

        return try block()
    }
}
