import Foundation
import Metal
import QuartzCore

/// Mirrors Madeira wineserver + wine_process boot order.
/// Real PE execution requires strong symbols from Madeira static libraries.
/// Without them, bridges return failure — never reports fake success.
enum MadeiraBootSequence {

    enum Step: String {
        case jitCheck = "jit_check_debugged"
        case fexInit = "fex_initialize"
        case prefixPrepare = "prefix_prepare"
        case wineserver = "wineserver_start"
        case wineProcess = "wine_process_start"
        case running = "wine_process_running"
    }

    struct Outcome: Sendable {
        let ok: Bool
        let failedStep: Step?
        let message: String
    }

    /// Register the CAMetalLayer DXMT will present into.
    static func attachMetalLayer(_ layer: CAMetalLayer) {
        madeira_display_set_layer(layer)
    }

    static func isJITReady() -> Bool {
        jit_check_debugged()
    }

    /// Ensure a prefix directory exists and is seeded from the bundled template.
    /// If `preferredPrefix` is provided (per-game container), use it; otherwise Documents/wine.
    static func ensurePrefix(preferredPrefix: URL? = nil) -> (path: String, error: String?) {
        let prefix: URL
        if let preferredPrefix {
            prefix = preferredPrefix
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            prefix = docs.appendingPathComponent("wine", isDirectory: true)
        }

        let driveC = prefix.appendingPathComponent("drive_c", isDirectory: true)
        if FileManager.default.fileExists(atPath: driveC.path) {
            return (prefix.path, nil)
        }

        try? FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)

        let candidates: [URL] = [
            Bundle.main.url(forResource: "prefix-template", withExtension: "tar.gz", subdirectory: "Runtime"),
            Bundle.main.resourceURL?.appendingPathComponent("Runtime/prefix-template.tar.gz"),
            Bundle.main.url(forResource: "prefix-template", withExtension: "tar.gz"),
        ].compactMap { $0 }

        guard let tgz = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            try? FileManager.default.createDirectory(at: driveC, withIntermediateDirectories: true)
            return (prefix.path, "prefix-template.tar.gz not in bundle; empty prefix directory created")
        }

        let rc = madeira_extract_prefix_tgz(tgz.path, prefix.path)
        if rc != 0 {
            try? FileManager.default.createDirectory(at: driveC, withIntermediateDirectories: true)
            return (prefix.path, "madeira_extract_prefix_tgz failed (\(rc))")
        }
        return (prefix.path, nil)
    }

    /// Full host boot against a specific prefix (and optional executable).
    /// Returns only ok=true if `wine_process_is_running()` becomes true.
    static func runFullSequence(
        prefixURL: URL? = nil,
        executableURL: URL? = nil
    ) -> Outcome {
        jit_install_trap_handler()

        guard jit_check_debugged() else {
            return Outcome(
                ok: false,
                failedStep: .jitCheck,
                message: "CS_DEBUGGED not set. Enable JIT (StikDebug/StikJIT) before Wine/FEX."
            )
        }

        if !fex_initialize() {
            NSLog("[GameHub] fex_initialize returned false (libFEXCore may be missing)")
        }

        let prefix = ensurePrefix(preferredPrefix: prefixURL)
        if let err = prefix.error {
            NSLog("[GameHub] prefix: \(err)")
        }

        // If we have a specific .exe, copy/link it into the prefix drive_c for Wine to find
        if let exe = executableURL {
            placeExecutableInPrefix(exe: exe, prefixPath: prefix.path)
        }

        ws_log_quiet = 1

        let ws = wineserver_start(prefix.path)
        guard ws == 0 else {
            return Outcome(
                ok: false,
                failedStep: .wineserver,
                message: "wineserver_start failed (\(ws)). Link libwineserver.a from Madeira host build."
            )
        }

        for _ in 0..<50 {
            if wineserver_is_running() != 0 { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard wineserver_is_running() != 0 else {
            return Outcome(
                ok: false,
                failedStep: .wineserver,
                message: "wineserver thread never became ready"
            )
        }

        let wp = wine_process_start(prefix.path)
        guard wp == 0 else {
            return Outcome(
                ok: false,
                failedStep: .wineProcess,
                message: "wine_process_start failed (\(wp)). Need libntdll_unix.a + WineProcessBridge."
            )
        }

        for _ in 0..<100 {
            if wine_process_is_running() != 0 {
                return Outcome(ok: true, failedStep: nil, message: "Wine process thread running")
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        return Outcome(
            ok: false,
            failedStep: .running,
            message: "wine_process_start returned 0 but process not observed running"
        )
    }

    /// Copy the imported .exe into the prefix's drive_c so Wine can resolve it.
    private static func placeExecutableInPrefix(exe: URL, prefixPath: String) {
        let fm = FileManager.default
        let driveC = URL(fileURLWithPath: prefixPath).appendingPathComponent("drive_c", isDirectory: true)
        try? fm.createDirectory(at: driveC, withIntermediateDirectories: true)
        let dest = driveC.appendingPathComponent(exe.lastPathComponent)
        if fm.fileExists(atPath: dest.path) {
            try? fm.removeItem(at: dest)
        }
        // Hard-link when possible (same volume); else copy
        do {
            try fm.linkItem(at: exe, to: dest)
        } catch {
            try? fm.copyItem(at: exe, to: dest)
        }
        NSLog("[GameHub] placed executable at \(dest.path)")
    }
}
