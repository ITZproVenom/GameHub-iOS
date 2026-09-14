import Foundation

/// Expected on-disk layout for a Madeira-compatible runtime bundle.
/// Aligns with Madeira (willfaust/Madeira) product names where possible.
struct RuntimeBundleLayout: Sendable {
    let root: URL

    /// Core files the host expects before attempting a real launch.
    static let requiredRelativePaths: [String] = [
        "VERSION",
        "wine64",
        "FEXInterpreter",
        "dxmt11.dylib",
    ]

    /// Optional / progressive components (reported, not all required for "installed").
    static let optionalRelativePaths: [String] = [
        "wineserver",
        "libdxmt_unix.a",
        "prefix-template.tar.gz",
    ]

    init(root: URL) {
        self.root = root
    }

    func url(forRelative path: String) -> URL {
        root.appendingPathComponent(path)
    }

    func missingRequired() -> [String] {
        Self.requiredRelativePaths.filter {
            !FileManager.default.fileExists(atPath: url(forRelative: $0).path)
        }
    }

    func presentOptional() -> [String] {
        Self.optionalRelativePaths.filter {
            FileManager.default.fileExists(atPath: url(forRelative: $0).path)
        }
    }

    var hasVersionFile: Bool {
        FileManager.default.fileExists(atPath: url(forRelative: "VERSION").path)
    }

    func readVersion() -> String? {
        let path = url(forRelative: "VERSION")
        guard let data = try? Data(contentsOf: path),
              let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return nil }
        return text
    }

    /// Candidate roots: app Resources/Runtime, Application Support, Documents.
    static func discoverRoots() -> [URL] {
        var roots: [URL] = []
        if let res = Bundle.main.resourceURL?.appendingPathComponent("Runtime", isDirectory: true) {
            roots.append(res)
        }
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            roots.append(appSupport.appendingPathComponent("GameHubData/Runtime", isDirectory: true))
        }
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            roots.append(docs.appendingPathComponent("Runtime", isDirectory: true))
        }
        return roots
    }

    static func firstExistingRoot() -> URL? {
        discoverRoots().first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

struct RuntimeComponentStatus: Identifiable, Sendable {
    let id: String
    let name: String
    let required: Bool
    let present: Bool
    let detail: String
}

enum RuntimeIntegrationReport: Sendable {
    case noBundleDirectory
    case incomplete(missing: [String], presentOptional: [String], version: String?)
    case ready(version: String, presentOptional: [String])

    var canAttemptLaunch: Bool {
        if case .ready = self { return true }
        return false
    }
}
