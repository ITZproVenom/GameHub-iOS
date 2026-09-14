import Foundation

/// On-disk layout matching **Madeira** packaged products
/// (willfaust/Madeira @ 97e2ce26…).
///
/// Madeira does **not** ship a standalone `wine64` binary. Host Wine and FEX
/// run in-process via static libraries + bridges. What *is* distributed as
/// discrete files are PE sysroots, xtajit64, DXMT PE DLLs, crypto libs, and
/// a Wine prefix template.
struct RuntimeBundleLayout: Sendable {
    let root: URL

    /// Minimum discrete files/dirs for a Madeira-compatible sysroot bundle.
    static let requiredMarkers: [String] = [
        "VERSION",
        "aarch64-windows",
        "arm64ec-windows",
        "prefix-template.tar.gz",
    ]

    /// Key PE / translation surfaces that must resolve under a sysroot.
    static let requiredPENames: [String] = [
        "d3d11.dll",
        "dxgi.dll",
        "xtajit64.dll",
    ]

    init(root: URL) {
        self.root = root
    }

    func url(forRelative path: String) -> URL {
        root.appendingPathComponent(path)
    }

    func missingMarkers() -> [String] {
        Self.requiredMarkers.filter { marker in
            !FileManager.default.fileExists(atPath: url(forRelative: marker).path)
        }
    }

    func findPE(_ name: String) -> URL? {
        let candidates = [
            url(forRelative: "arm64ec-windows").appendingPathComponent(name),
            url(forRelative: "aarch64-windows").appendingPathComponent(name),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    func missingPE() -> [String] {
        Self.requiredPENames.filter { findPE($0) == nil }
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

    /// Host Wine/FEX bridges are separate from the PE bundle.
    var hasInProcessHostHint: Bool {
        // Future: detect linked Madeira bridges or libwine symbols.
        FileManager.default.fileExists(atPath: url(forRelative: "libdxmt_unix.a").path)
            || FileManager.default.fileExists(atPath: url(forRelative: "wine64").path)
    }

    static func discoverRoots() -> [URL] {
        var roots: [URL] = []
        if let res = Bundle.main.resourceURL?.appendingPathComponent("Runtime", isDirectory: true) {
            roots.append(res)
        }
        // Xcode often flattens resource folders next to the executable.
        if let bundled = Bundle.main.url(forResource: "VERSION", withExtension: nil)?
            .deletingLastPathComponent() {
            roots.append(bundled)
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
        discoverRoots().first { root in
            FileManager.default.fileExists(atPath: root.appendingPathComponent("VERSION").path)
                || FileManager.default.fileExists(atPath: root.appendingPathComponent("aarch64-windows").path)
        }
    }
}

enum RuntimeIntegrationReport: Sendable {
    case noBundleDirectory
    /// PE/sysroot present; in-process Wine/FEX host still required for launch.
    case sysrootReady(version: String, missingHost: Bool)
    case incomplete(missing: [String])

    var canAttemptLaunch: Bool {
        // Only attempt when host exists; sysroot alone is not enough.
        if case .sysrootReady(_, let missingHost) = self { return !missingHost }
        return false
    }
}
