import Foundation
import Metal
import QuartzCore

/// Mirrors Madeira `ContentView.runWineFullSequence` / wineserver + wine_process order.
/// Real PE execution requires strong symbols from Madeira static libraries
/// (`libwineserver.a`, `libntdll_unix.a`, `libFEXCore.a`, `libdxmt_combined.a`, …).
/// Without them, weak stubs return failure — never reports fake success.
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

    /// Register the CAMetalLayer DXMT will present into (Madeira `madeira_display_set_layer`).
    static func attachMetalLayer(_ layer: CAMetalLayer) {
        madeira_display_set_layer(layer)
    }

    static func isJITReady() -> Bool {
        jit_check_debugged()
    }

    /// Prepare Documents/wine prefix from Runtime/prefix-template.tar.gz when available.
    static func ensurePrefix() -> (path: String, error: String?) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let prefix = docs.appendingPathComponent("wine", isDirectory: true)
        let driveC = prefix.appendingPathComponent("drive_c", isDirectory: true)
        if FileManager.default.fileExists(atPath: driveC.path) {
            return (prefix.path, nil)
        }
        try? FileManager.default.createDirectory(at: prefix, withIntermediateDirectories: true)

        let candidates: [URL] = [
            Bundle.main.resourceURL?.appendingPathComponent("Runtime/prefix-template.tar.gz"),
            Bundle.main.url(forResource: "prefix-template", withExtension: "tar.gz"),
            Bundle.main.url(forResource: "prefix-template", withExtension: "tar.gz", subdirectory: "Runtime"),
        ].compactMap { $0 }

        guard let tgz = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return (prefix.path, "prefix-template.tar.gz not in bundle; empty prefix directory created")
        }
        let rc = madeira_extract_prefix_tgz(tgz.path, prefix.path)
        if rc != 0 {
            return (prefix.path, "madeira_extract_prefix_tgz failed (\(rc)) — need PrefixExtractor linked or manual prefix")
        }
        return (prefix.path, nil)
    }

    /// Full host boot. Returns only ok=true if `wine_process_is_running()` becomes true.
    static func runFullSequence() -> Outcome {
        jit_install_trap_handler()

        guard jit_check_debugged() else {
            return Outcome(
                ok: false,
                failedStep: .jitCheck,
                message: "CS_DEBUGGED not set. Enable JIT (StikDebug/StikJIT) before Wine/FEX."
            )
        }

        // Optional FEX self-test (strong symbol required for real translation).
        if !fex_initialize() {
            // Continue: some Madeira paths init FEX inside wine; still record.
            NSLog("[GameHub] fex_initialize returned false (libFEXCore may be missing)")
        }

        let prefix = ensurePrefix()
        if let err = prefix.error {
            NSLog("[GameHub] prefix: \(err)")
        }

        ws_log_quiet = 1

        let ws = wineserver_start(prefix.path)
        guard ws == 0 else {
            return Outcome(
                ok: false,
                failedStep: .wineserver,
                message: "wineserver_start failed (\(ws)). Link libwineserver.a from Madeira build."
            )
        }

        // Brief wait for server thread
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
                message: "wine_process_start failed (\(wp)). Link Wine unix host (libntdll_unix.a / Madeira WineProcessBridge.m)."
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
}
