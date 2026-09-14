import Foundation

enum RuntimeCapability: String, CaseIterable, Sendable {
    case wineExecution
    case x86Translation
    case d3d11ToMetal
    case audioOutput
    case inputCapture
    case jitCompilation
    case dynamicLibraryLoading
}

enum RuntimeState: Sendable {
    case unavailable
    case installed(version: String)
    case updateAvailable(current: String, latest: String)
    case error(String)
}

enum LaunchResult: Sendable {
    case success
    case successLaunched(pid: pid_t)
    case unsupported(String)
    case runtimeNotInstalled
    case binaryMissing(String)
    case entitlementRequired(String)
    case error(String)
}

protocol RuntimeProvider: AnyObject, Sendable {
    var id: String { get }
    var name: String { get }
    var description: String { get }
    var projectURL: String { get }
    var pinnedCommit: String? { get }

    func currentState() async -> RuntimeState
    func supportedCapabilities() async -> Set<RuntimeCapability>
    func isCapabilityAvailable(_ capability: RuntimeCapability) async -> Bool
    func launch(
        executableURL: URL,
        prefixURL: URL,
        arguments: [String],
        environment: [String: String],
        config: RuntimeConfig
    ) async -> LaunchResult
    func stopRunningProcesses() async
    func runtimeStatus() async -> RuntimeStatus
}

struct RuntimeStatus: Sendable, Identifiable {
    let id: String
    let providerName: String
    let state: RuntimeState
    let capabilities: [RuntimeCapabilityReport]
    let lastChecked: Date

    struct RuntimeCapabilityReport: Sendable, Identifiable {
        let id: String
        let capability: RuntimeCapability
        let available: Bool
        let reason: String?

        init(capability: RuntimeCapability, available: Bool, reason: String? = nil) {
            self.id = capability.rawValue
            self.capability = capability
            self.available = available
            self.reason = reason
        }
    }
}

extension RuntimeCapability {
    var displayName: String {
        switch self {
        case .wineExecution: return "Wine Execution"
        case .x86Translation: return "x86-64 → ARM64 Translation"
        case .d3d11ToMetal: return "D3D11 → Metal (DXMT)"
        case .audioOutput: return "Audio Output"
        case .inputCapture: return "Input Capture"
        case .jitCompilation: return "JIT Compilation"
        case .dynamicLibraryLoading: return "Dynamic Library Loading"
        }
    }
}
