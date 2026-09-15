import Foundation

/// Madeira-style host: in-process wineserver + wine_process after JIT.
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
        let hasSysroot: Bool = {
            guard let bundle = bundleLayout() else { return false }
            return bundle.missingMarkers().isEmpty && bundle.missingPE().isEmpty
        }()
        let version = bundleLayout()?.readVersion() ?? "host"
        return .sysrootReady(version: version, missingHost: false)
    }

    func currentState() async -> RuntimeState {
        if MadeiraBootSequence.isJITReady() {
            return .installed(version: bundleLayout()?.readVersion() ?? "jit-ready")
        }
        return .error(
            "JIT not enabled (CS_DEBUGGED). Attach StikDebug/StikJIT, then launch. "
            + "Wine host requires libwineserver.a + libntdll_unix.a from Madeira build "
            + "(\(projectURL) @ \(pinnedCommit ?? ""))."
        )
    }

    func supportedCapabilities() async -> Set<RuntimeCapability> {
        [.wineExecution, .x86Translation, .d3d11ToMetal, .audioOutput, .inputCapture,
         .jitCompilation, .dynamicLibraryLoading]
    }

    func isCapabilityAvailable(_ capability: RuntimeCapability) async -> Bool {
        capability == .jitCompilation ? MadeiraBootSequence.isJITReady() : true
    }

    func launch(
        executableURL: URL,
        prefixURL: URL,
        arguments: [String],
        environment: [String: String],
        config: RuntimeConfig
    ) async -> LaunchResult {
        _ = arguments
        _ = environment
        _ = config

        // Place the selected .exe into the game's Wine prefix and boot
        // wineserver → wine_process. Metal layer must already be registered by UI.
        let outcome = MadeiraBootSequence.runFullSequence(
            prefixURL: prefixURL,
            executableURL: executableURL
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
            reports.append(.init(
                capability: cap,
                available: available,
                reason: available ? nil : "JIT or Madeira static host missing"
            ))
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
