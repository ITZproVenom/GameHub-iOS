import Foundation

/// Integrates **Madeira** (Wine + FEX + DXMT) artifacts.
///
/// Upstream products discrete files for PE sysroots / xtajit / DXMT PE and
/// links host Wine/FEX into the iOS process. This provider never fakes a
/// successful Windows launch without a real host path.
final class MadeiraRuntimeProvider: RuntimeProvider, @unchecked Sendable {
    let id = "madeira"
    let name = "Madeira"
    let description = "Wine (in-process) + FEX/xtajit64 + DXMT PE — Madeira layout"
    let projectURL = GameHubConstants.madeiraProjectURL
    let pinnedCommit: String? = GameHubConstants.madeiraPinnedCommit

    private let forcedRoot: URL?

    init(binaryDirectory: URL? = nil) {
        self.forcedRoot = binaryDirectory
    }

    private func layout() -> RuntimeBundleLayout? {
        if let forcedRoot { return RuntimeBundleLayout(root: forcedRoot) }
        guard let root = RuntimeBundleLayout.firstExistingRoot() else { return nil }
        return RuntimeBundleLayout(root: root)
    }

    func integrationReport() -> RuntimeIntegrationReport {
        guard let layout else { return .noBundleDirectory }
        var missing = layout.missingMarkers()
        missing.append(contentsOf: layout.missingPE())
        if !missing.isEmpty {
            return .incomplete(missing: missing)
        }
        let version = layout.readVersion() ?? "madeira-sysroot"
        // Host Wine is not a separate wine64 in Madeira; until bridges are
        // linked into GameHub, missingHost stays true.
        let missingHost = !layout.hasInProcessHostHint && !FileManager.default.fileExists(
            atPath: layout.url(forRelative: "wine64").path
        )
        // libdxmt_unix.a alone is not a full host — still mark host missing
        // unless wine64 exists (experimental external spawn) or a future flag.
        let hostReady = FileManager.default.fileExists(
            atPath: layout.url(forRelative: "wine64").path
        )
        return .sysrootReady(version: version, missingHost: !hostReady)
    }

    func currentState() async -> RuntimeState {
        switch integrationReport() {
        case .noBundleDirectory:
            return .unavailable
        case .incomplete(let missing):
            return .error("Runtime incomplete: \(missing.joined(separator: ", "))")
        case .sysrootReady(let version, let missingHost):
            if missingHost {
                return .error(
                    "Madeira PE sysroot \(version) is present (DXMT/xtajit/prefix), "
                    + "but in-process Wine/FEX host is not linked into this build. "
                    + "Madeira does not ship standalone wine64 — host is built into "
                    + "Madeira.app via static libs + bridges. See \(projectURL) @ \(pinnedCommit ?? "")."
                )
            }
            return .installed(version: version)
        }
    }

    func supportedCapabilities() async -> Set<RuntimeCapability> {
        [.wineExecution, .x86Translation, .d3d11ToMetal, .audioOutput, .inputCapture,
         .jitCompilation, .dynamicLibraryLoading]
    }

    func isCapabilityAvailable(_ capability: RuntimeCapability) async -> Bool {
        let state = await currentState()
        guard case .installed = state else { return false }
        return true
    }

    func launch(
        executableURL: URL,
        prefixURL: URL,
        arguments: [String],
        environment: [String: String],
        config: RuntimeConfig
    ) async -> LaunchResult {
        let report = integrationReport()
        switch report {
        case .noBundleDirectory, .incomplete:
            return .runtimeNotInstalled
        case .sysrootReady(_, true):
            return .binaryMissing(
                "PE sysroot is installed but Wine host is not available in this app binary. "
                + "Integrate Madeira WineProcessBridge / static Wine (no standalone wine64)."
            )
        case .sysrootReady(let version, false):
            break
        }

        guard let layout,
              FileManager.default.fileExists(atPath: layout.url(forRelative: "wine64").path)
        else {
            return .binaryMissing("wine64 not present")
        }

        var env = environment
        env["WINEPREFIX"] = prefixURL.path
        env["WINEARCH"] = "win64"
        env["MADEIRA_VERSION"] = layout.readVersion() ?? "unknown"
        env["WINEDLLPATH"] = layout.url(forRelative: "arm64ec-windows").path

        do {
            let result = try NativeProcessLauncher.run(
                executable: layout.url(forRelative: "wine64"),
                arguments: [executableURL.path] + arguments,
                environment: env,
                workingDirectory: executableURL.deletingLastPathComponent()
            )
            return result.status == 0 ? .successLaunched(pid: result.pid) : .error("exit \(result.status)")
        } catch {
            return .error(error.localizedDescription)
        }
    }

    func stopRunningProcesses() async {
        NativeProcessLauncher.terminate(names: ["wine64", "wine", "wineserver"])
    }

    func runtimeStatus() async -> RuntimeStatus {
        let state = await currentState()
        let capabilities = await supportedCapabilities()
        var reports: [RuntimeStatus.RuntimeCapabilityReport] = []
        for cap in capabilities {
            let available = await isCapabilityAvailable(cap)
            reports.append(.init(capability: cap, available: available, reason: available ? nil : "Host or sysroot incomplete"))
        }
        return RuntimeStatus(
            id: id,
            providerName: name,
            state: state,
            capabilities: reports.sorted { $0.capability.rawValue < $1.capability.rawValue },
            lastChecked: Date()
        )
    }
}
