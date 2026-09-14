import Foundation

final class MadeiraRuntimeProvider: RuntimeProvider, @unchecked Sendable {
    let id = "madeira"
    let name = "Madeira"
    let description = "Wine ARM64EC + FEX-Emu x86-64 translation + DXMT D3D11→Metal"
    let projectURL = GameHubConstants.madeiraProjectURL
    let pinnedCommit = GameHubConstants.madeiraPinnedCommit

    private let binaryDirectory: URL?
    private let installedVersion: String?

    init(binaryDirectory: URL? = nil) {
        self.binaryDirectory = binaryDirectory
        self.installedVersion = binaryDirectory.flatMap { dir in
            let versionFile = dir.appendingPathComponent("VERSION")
            guard let data = try? Data(contentsOf: versionFile),
                  let version = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !version.isEmpty
            else {
                return nil
            }
            return version
        }
    }

    // MARK: - Runtime State

    func currentState() async -> RuntimeState {
        guard let binaryDirectory else {
            return .unavailable
        }

        let wineBinary = binaryDirectory.appendingPathComponent("wine64")
        let fexBinary = binaryDirectory.appendingPathComponent("FEXInterpreter")
        let dxmtBinary = binaryDirectory.appendingPathComponent("dxmt11.dylib")

        let binariesExist = FileManager.default.fileExists(atPath: wineBinary.path)
            && FileManager.default.fileExists(atPath: fexBinary.path)
            && FileManager.default.fileExists(atPath: dxmtBinary.path)

        guard binariesExist else {
            let missing = [
                !FileManager.default.fileExists(atPath: wineBinary.path) ? "wine64" : nil,
                !FileManager.default.fileExists(atPath: fexBinary.path) ? "FEXInterpreter" : nil,
                !FileManager.default.fileExists(atPath: dxmtBinary.path) ? "dxmt11.dylib" : nil,
            ].compactMap { $0 }
            return .error("Missing binaries: \(missing.joined(separator: ", ")). "
                + "The Madeira runtime must be compiled and placed in: \(binaryDirectory.path). "
                + "See \(projectURL) at commit \(pinnedCommit ?? "unknown").")
        }

        let version = installedVersion ?? "unknown"
        return .installed(version: version)
    }

    // MARK: - Capabilities

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
            return await jitEntitlementEnabled()
        }
    }

    // MARK: - Launch

    func launch(
        executableURL: URL,
        prefixURL: URL,
        arguments: [String],
        environment: [String: String],
        config: RuntimeConfig
    ) async -> LaunchResult {
        let state = await currentState()

        guard case .installed(let version) = state else {
            return .runtimeNotInstalled
        }

        guard let binaryDirectory else {
            return .binaryMissing("Madeira binary directory not configured")
        }

        let fexBinary = binaryDirectory.appendingPathComponent("FEXInterpreter")
        guard FileManager.default.fileExists(atPath: fexBinary.path) else {
            return .binaryMissing("FEXInterpreter not found at \(fexBinary.path). "
                + "Compile Madeira from \(projectURL) at commit \(pinnedCommit ?? "unknown").")
        }

        if !await jitEntitlementEnabled() {
            return .entitlementRequired(
                "JIT compilation entitlement is required for x86-64 translation. "
                + "The app must be built with the com.apple.security.cs.allow-jit entitlement "
                + "and run on a device with JIT support.")
        }

        var env = environment
        env["WINEPREFIX"] = prefixURL.path
        env["WINEARCH"] = config.windowsVersion == .win7 ? "win32" : "win64"
        env["MADEIRA_VERSION"] = version
        env["DXMT_ENABLED"] = config.dxmtEnabled ? "1" : "0"
        env["DXVK_ENABLED"] = config.dxvkEnabled ? "1" : "0"

        let task = Process()
        task.executableURL = fexBinary
        task.arguments = [executableURL.path] + arguments
        task.environment = env
        task.currentDirectoryURL = executableURL.deletingLastPathComponent()

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                return .success
            } else {
                return .error("Process exited with status \(task.terminationStatus)")
            }
        } catch {
            return .error("Failed to launch process: \(error.localizedDescription)")
        }
    }

    func stopRunningProcesses() async {
        let running = Process()
        running.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        running.arguments = ["wine64", "FEXInterpreter"]
        try? running.run()
        running.waitUntilExit()
    }

    func runtimeStatus() async -> RuntimeStatus {
        let state = await currentState()
        let capabilities = await supportedCapabilities()

        let reports: [RuntimeStatus.RuntimeCapabilityReport] = await withTaskGroup(of: RuntimeStatus.RuntimeCapabilityReport.self) { group in
            for cap in capabilities {
                group.addTask { [self] in
                    let available = await self.isCapabilityAvailable(cap)
                    let reason: String? = available ? nil : "Runtime binaries not installed or JIT entitlement missing"
                    return RuntimeStatus.RuntimeCapabilityReport(capability: cap, available: available, reason: reason)
                }
            }

            var results: [RuntimeStatus.RuntimeCapabilityReport] = []
            for await report in group {
                results.append(report)
            }
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

    // MARK: - Private

    private func jitEntitlementEnabled() async -> Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
}