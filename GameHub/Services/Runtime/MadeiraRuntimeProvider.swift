import Foundation

/// Madeira-style host: in-process wineserver + wine_process after JIT.
/// Without JIT the provider still reports status and allows prefix/library work;
/// launch refuses with a clear entitlement message.
final class MadeiraRuntimeProvider: RuntimeProvider, @unchecked Sendable {
    let id = "madeira"
    let name = "Madeira"
    let description = "In-process Wine/FEX/DXMT (Madeira boot sequence)"
    let projectURL = GameHubConstants.madeiraProjectURL
    let pinnedCommit: String? = GameHubConstants.madeiraPinnedCommit

    private let forcedRoot: URL?

    init(binaryDirectory: URL? = nil) {
        self.forcedRoot = binaryDirectory
    }

    private func bundleLayout() -> RuntimeBundleLayout? {
        if let forcedRoot { return RuntimeBundleLayout(root: forcedRoot) }
        guard let root = RuntimeBundleLayout.firstExistingRoot() else { return nil }
        return RuntimeBundleLayout(root: root)
    }

    func integrationReport() -> RuntimeIntegrationReport {
        let version = bundleLayout()?.readVersion() ?? "host"
        return .sysrootReady(version: version, missingHost: false)
    }

    func currentState() async -> RuntimeState {
        let version = bundleLayout()?.readVersion() ?? "runtime"
        if MadeiraBootSequence.isJITReady() {
            return .installed(version: "\(version) · JIT ready")
        }
        return .error(
            "JIT required for x86-64 execution. "
            + "Attach StikDebug / StikJIT / TrollStore, then relaunch. "
            + "Library, import, and prefixes still work."
        )
    }

    func supportedCapabilities() async -> Set<RuntimeCapability> {
        [.wineExecution, .x86Translation, .d3d11ToMetal, .audioOutput, .inputCapture,
         .jitCompilation, .dynamicLibraryLoading]
    }

    func isCapabilityAvailable(_ capability: RuntimeCapability) async -> Bool {
        switch capability {
        case .jitCompilation, .x86Translation, .wineExecution:
            return MadeiraBootSequence.isJITReady()
        default:
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
        _ = config

        let outcome = MadeiraBootSequence.runFullSequence(
            prefixURL: prefixURL,
            executableURL: executableURL,
            arguments: arguments,
            environment: environment
        )

        if outcome.ok {
            return .success
        }
        if outcome.failedStep == .jitCheck {
            return .entitlementRequired(outcome.message)
        }
        if outcome.failedStep == .wineserver || outcome.failedStep == .wineProcess {
            return .binaryMissing(outcome.message)
        }
        return .error(outcome.message)
    }

    func stopRunningProcesses() async {
        wineserver_stop()
    }

    func runtimeStatus() async -> RuntimeStatus {
        let state = await currentState()
        let capabilities = await supportedCapabilities()
        var reports: [RuntimeStatus.RuntimeCapabilityReport] = []
        for cap in capabilities {
            let available = await isCapabilityAvailable(cap)
            let reason: String?
            if available {
                reason = nil
            } else if cap == .jitCompilation || cap == .x86Translation || cap == .wineExecution {
                reason = "Requires JIT debugger (StikDebug / StikJIT / TrollStore)"
            } else {
                reason = "Unavailable"
            }
            reports.append(.init(capability: cap, available: available, reason: reason))
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
