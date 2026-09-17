import Foundation
import UIKit
import Metal
import QuartzCore

/// Mirrors Madeira wineserver + wine_process boot order.
/// Real PE execution requires JIT (CS_DEBUGGED) + Madeira static host libraries.
/// Without JIT, the app still manages library / prefix / config; launch refuses honestly.
enum MadeiraBootSequence {

    enum Step: String {
        case jitCheck = "jit_check_debugged"
        case fexInit = "fex_initialize"
        case dxmtInit = "dxmt_initialize"
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

    static let noJITUserMessage =
        "JIT is not enabled on this device. "
        + "Library, import, and prefix management still work, but x86-64 game execution "
        + "requires a JIT debugger (StikDebug / StikJIT / TrollStore). "
        + "Attach one, then launch again."

    static func attachMetalLayer(_ layer: CAMetalLayer) {
        madeira_display_set_layer(layer)
    }

    static func isJITReady() -> Bool {
        jit_check_debugged()
    }

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

    static func bindPresentationLayerIfPossible() {
        let work = {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
            guard let window else { return }
            MetalHostView.shared.install(on: window, frame: window.bounds)
            MetalHostView.shared.isHidden = false
            window.bringSubviewToFront(MetalHostView.shared)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }

    static func runFullSequence(
        prefixURL: URL? = nil,
        executableURL: URL? = nil,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) -> Outcome {
        jit_install_trap_handler()
        bindPresentationLayerIfPossible()

        guard jit_check_debugged() else {
            return Outcome(
                ok: false,
                failedStep: .jitCheck,
                message: noJITUserMessage
            )
        }

        if !fex_initialize() {
            return Outcome(
                ok: false,
                failedStep: .fexInit,
                message: "fex_initialize failed. JIT is present but libFEXCore.a did not probe. Cannot translate x86-64."
            )
        }

        if !dxmt_initialize() {
            NSLog("[GameHub] dxmt_initialize returned false (no Metal device)")
            return Outcome(
                ok: false,
                failedStep: .dxmtInit,
                message: "dxmt_initialize failed: no Metal device on this host"
            )
        }

        let prefix = ensurePrefix(preferredPrefix: prefixURL)
        if let err = prefix.error {
            NSLog("[GameHub] prefix: \(err)")
        }

        var placedWinPath: String? = nil
        if let exe = executableURL {
            placedWinPath = placeExecutableInPrefix(exe: exe, prefixPath: prefix.path)
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

        let extra = arguments.joined(separator: " ")
        let envBlock = environment.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        wine_process_configure(extra.isEmpty ? nil : extra, envBlock.isEmpty ? nil : envBlock)

        let wp: Int32
        if let win = placedWinPath {
            wp = wine_process_start_exe(prefix.path, win)
        } else {
            wp = wine_process_start(prefix.path)
        }
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

    @discardableResult
    private static func placeExecutableInPrefix(exe: URL, prefixPath: String) -> String {
        let fm = FileManager.default
        let driveC = URL(fileURLWithPath: prefixPath).appendingPathComponent("drive_c", isDirectory: true)
        try? fm.createDirectory(at: driveC, withIntermediateDirectories: true)
        let dest = driveC.appendingPathComponent(exe.lastPathComponent)
        if fm.fileExists(atPath: dest.path) {
            try? fm.removeItem(at: dest)
        }
        do {
            try fm.linkItem(at: exe, to: dest)
        } catch {
            try? fm.copyItem(at: exe, to: dest)
        }
        NSLog("[GameHub] placed executable at \(dest.path)")
        return "C:\\" + exe.lastPathComponent
    }
}
