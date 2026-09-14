import Foundation

/// Host-side integration with the Madeira runtime stack
/// (Wine ARM64EC + FEX + DXMT). Does **not** fabricate launches.
///
/// Binaries must be placed under a discovered Runtime root (see
/// `RuntimeBundleLayout`). Upstream: https://github.com/willfaust/Madeira
/// pinned commit via `GameHubConstants.madeiraPinnedCommit`.
final class MadeiraRuntimeProvider: RuntimeProvider, @unchecked Sendable {
    let id = "madeira"
    let name = "Madeira"
    let description = "Wine ARM64EC + FEX-Emu x86-64 translation + DXMT D3D11→Metal"
    let projectURL = GameHubConstants.madeiraProjectURL
    let pinnedCommit: String? = GameHubConstants.madeiraPinnedCommit

    private let forcedRoot: URL?

    init(binaryDirectory: URL? = nil) {
        self.forcedRoot = binaryDirectory
    }

    private func layout() -> RuntimeBundleLayout? {
        if let forcedRoot {
            return RuntimeBundleLayout(root: forcedRoot)
        }
        guard let root = RuntimeBundleLayout.firstExistingRoot() else { return nil }
        return RuntimeBundleLayout(root: root)
    }

    func integrationReport() -> RuntimeIntegrationReport {
        guard let layout else { return .noBundleDirectory }
        let missing = layout.missingRequired()
        let optional = layout.presentOptional()
        let version = layout.readVersion()
        if missing.isEmpty {
            return .ready(version: version ?? "unknown", presentOptional: optional)
        }
        return .incomplete(missing: missing, presentOptional: optional, version: version)
    }

    func componentStatuses() -> [RuntimeComponentStatus] {
        guard let layout else {
            return RuntimeBundleLayout.requiredRelativePaths.map {
                RuntimeComponentStatus(
                    id: $0,
                    name: $0,
                    required: true,
                    present: false,
                    detail: "Runtime directory not found. Place binaries under Documents/Runtime or App Support/GameHubData/Runtime."
                )
            }
        }
        var rows: [RuntimeComponentStatus] = []
        for path in RuntimeBundleLayout.requiredRelativePaths {
            let present = FileManager.default.fileExists(atPath: layout.url(forRelative: path).path)
            rows.append(RuntimeComponentStatus(
                id: path,
                name: path,
                required: true,
                present: present,
                detail: present ? "Found" : "Missing required file"
            ))
        }
        for path in RuntimeBundleLayout.optionalRelativePaths {
            let present = FileManager.default.fileExists(atPath: layout.url(forRelative: path).path)
            rows.append(RuntimeComponentStatus(
                id: path,
                name: path,
                required: false,
                present: present,
                detail: present ? "Found" : "Optional"
            ))
        }
        return rows
    }

    func currentState() async -> RuntimeState {
        switch integrationReport() {
        case .noBundleDirectory:
            return .unavailable
        case .incomplete(let missing, _, _):
            return .error(
                "Runtime incomplete. Missing: \(missing.joined(separator: ", ")). "
                + "Build or copy Madeira products into the Runtime folder. "
                + "Upstream \(projectURL) @ \(pinnedCommit ?? "?"). "
                + "JIT on device requires a debugger attach (e.g. StikDebug) — see Madeira docs."
            )
        case .ready(let version, _):
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
        switch capability {
        case .wineExecution, .x86Translation, .d3d11ToMetal,
             .audioOutput, .inputCapture, .dynamicLibraryLoading:
            return true
        case .jitCompilation:
            // Presence of CS_DEBUGGED / StikDebug cannot be fully proven offline.
            // Report true only when binaries exist; launch path still may fail without JIT.
            return true
        }
    }

    func launch(
        executableURL: URL,
        prefixURL: URL,
        arguments: [String],
        environment: [String: String],
        config: RuntimeConfig
    ) async -> LaunchResult {
        let report = integrationReport()
        guard case .ready(let version, _) = report else {
            return .runtimeNotInstalled
        }
        guard let layout else {
            return .binaryMissing("Runtime directory not configured")
        }

        let wineBinary = layout.url(forRelative: "wine64")
        let fexBinary = layout.url(forRelative: "FEXInterpreter")

        var env = environment
        env["WINEPREFIX"] = prefixURL.path
        env["WINEARCH"] = config.windowsVersion == .win7 ? "win32" : "win64"
        env["MADEIRA_VERSION"] = version
        env["DXMT_ENABLED"] = config.dxmtEnabled ? "1" : "0"
        env["DXVK_ENABLED"] = config.dxvkEnabled ? "1" : "0"
        env["WINEDLLPATH"] = layout.root.path

        let launchBinary: URL
        let launchArguments: [String]
        if FileManager.default.fileExists(atPath: wineBinary.path) {
            launchBinary = wineBinary
            launchArguments = [executableURL.path] + arguments
        } else if FileManager.default.fileExists(atPath: fexBinary.path) {
            launchBinary = fexBinary
            launchArguments = [executableURL.path] + arguments
        } else {
            return .binaryMissing("Neither wine64 nor FEXInterpreter found under \(layout.root.path)")
        }

        do {
            let result = try NativeProcessLauncher.run(
                executable: launchBinary,
                arguments: launchArguments,
                environment: env,
                workingDirectory: executableURL.deletingLastPathComponent()
            )
            if result.status == 0 {
                if result.pid != 0 {
                    return .successLaunched(pid: result.pid)
                }
                return .success
            }
            return .error("Runtime process exited with status \(result.status)")
        } catch {
            return .error("Failed to launch runtime: \(error.localizedDescription)")
        }
    }

    func stopRunningProcesses() async {
        NativeProcessLauncher.terminate(names: ["wine64", "FEXInterpreter", "wine", "wineserver"])
    }

    func runtimeStatus() async -> RuntimeStatus {
        let state = await currentState()
        let capabilities = await supportedCapabilities()
        let reports: [RuntimeStatus.RuntimeCapabilityReport] = await withTaskGroup(
            of: RuntimeStatus.RuntimeCapabilityReport.self
        ) { group in
            for cap in capabilities {
                group.addTask { [self] in
                    let available = await self.isCapabilityAvailable(cap)
                    return RuntimeStatus.RuntimeCapabilityReport(
                        capability: cap,
                        available: available,
                        reason: available ? nil : "Runtime incomplete or not installed"
                    )
                }
            }
            var results: [RuntimeStatus.RuntimeCapabilityReport] = []
            for await report in group { results.append(report) }
            return results
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
