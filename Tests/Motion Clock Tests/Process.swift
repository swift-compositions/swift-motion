import Foundation

/// The fixture process: launched with or without the shim library in it from launch.
enum Fixture {
    /// Where the build puts its products, next to this test bundle.
    static var products: URL? {
        var image = unsafe Dl_info()
        guard unsafe dladdr(#dsohandle, &image) != 0, let name = unsafe image.dli_fname else { return nil }
        var url = URL(fileURLWithPath: unsafe String(cString: name))
        while url.pathExtension != "xctest", url.path != "/" { url.deleteLastPathComponent() }
        return url.path == "/" ? nil : url.deletingLastPathComponent()
    }

    static var library: String? { products?.appending(path: "libMotion Clock Shims.dylib").path }

    /// Runs the fixture and gives back its `key=value` lines, the values of a repeated key in order.
    static func run(_ arguments: [String], inserting: Bool) -> [String: [String]] {
        guard let products, let library else { return [:] }
        let process = Process()
        process.executableURL = products.appending(path: "Motion Fixture")
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["DYLD_INSERT_LIBRARIES"] = inserting ? library : nil
        process.environment = environment
        let pipe = Pipe()
        let complaints = Pipe()
        process.standardOutput = pipe
        process.standardError = complaints
        // swift-linter:disable:next do throws for typed catch
        // REASON: Process.run throws untyped; a fixture that cannot start prints nothing and every expectation on it fails.
        do {
            try process.run()
        } catch {
            return ["status": ["not started: \(error)"]]
        }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let complaint = String(decoding: complaints.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        var lines: [String: [String]] = ["status": ["\(process.terminationReason == .exit ? "exit" : "signal") \(process.terminationStatus)"]]
        if !complaint.isEmpty { lines["stderr"] = [String(complaint.prefix(600))] }
        output.split(separator: "\n").forEach { line in
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { return }
            lines[String(parts[0]), default: []].append(String(parts[1]))
        }
        return lines
    }
}
