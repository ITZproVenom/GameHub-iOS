import Foundation

actor RuntimeService {
    private var providers: [String: RuntimeProvider] = [:]
    private var activeProviderID: String = "madeira"

    init() {
        let madeira = MadeiraRuntimeProvider()
        providers[madeira.id] = madeira
    }

    var activeProvider: RuntimeProvider? {
        providers[activeProviderID]
    }

    func setActiveProvider(_ providerID: String) {
        guard providers[providerID] != nil else { return }
        activeProviderID = providerID
    }

    func register(provider: RuntimeProvider) {
        providers[provider.id] = provider
    }

    func availableProviders() -> [RuntimeProvider] {
        Array(providers.values)
    }

    func launchGame(
        game: Game,
        executableURL: URL,
        prefixURL: URL,
        environment: [String: String]
    ) async -> LaunchResult {
        guard let provider = activeProvider else {
            return .error("No runtime provider available")
        }

        return await provider.launch(
            executableURL: executableURL,
            prefixURL: prefixURL,
            arguments: game.launchArguments,
            environment: environment,
            config: game.runtimeConfig
        )
    }

    func stopAll() async {
        for provider in providers.values {
            await provider.stopRunningProcesses()
        }
    }

    func currentStatus() async -> [RuntimeStatus] {
        await withTaskGroup(of: RuntimeStatus.self) { group in
            for provider in providers.values {
                group.addTask { await provider.runtimeStatus() }
            }
            var results: [RuntimeStatus] = []
            for await status in group {
                results.append(status)
            }
            return results
        }
    }
}

enum RuntimeServiceHolder {
    static var shared: RuntimeService?

    static func stop() async {
        await shared?.stopAll()
    }
}
