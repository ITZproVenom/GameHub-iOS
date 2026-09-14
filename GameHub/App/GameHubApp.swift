import SwiftUI
import UniformTypeIdentifiers

@main
struct GameHubApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.libraryViewModel)
                .environmentObject(appState.settingsViewModel)
                .onAppear {
                    appState.libraryViewModel.refreshRuntimeStatus()
                }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings

    let storageService: StorageService
    let gameService: GameService
    let containerService: ContainerService
    let runtimeService: RuntimeService
    let logService: LogService
    let performanceMonitor: PerformanceMonitor
    let inputService: InputService
    let libraryViewModel: LibraryViewModel
    let settingsViewModel: SettingsViewModel

    init() {
        let storage = StorageService()
        self.storageService = storage

        let games = GameService(storage: storage)
        self.gameService = games

        let containers = ContainerService(storage: storage)
        self.containerService = containers
        containers.loadContainers()
        games.load()

        let runtime = RuntimeService()
        self.runtimeService = runtime

        let logs = LogService()
        self.logService = logs
        logs.info("GameHub started", category: "App")

        let perf = PerformanceMonitor()
        self.performanceMonitor = perf

        let input = InputService()
        self.inputService = input

        let saved = storage.load(AppSettings.self, from: "settings.json")
        let effective = saved ?? .default
        self.settings = effective
        try? storage.save(effective, to: "settings.json")
        Task {
            await runtime.setActiveProvider(effective.runtimeProviderID)
        }

        self.libraryViewModel = LibraryViewModel(
            gameService: games,
            containerService: containers,
            runtimeService: runtime,
            storageService: storage
        )
        self.settingsViewModel = SettingsViewModel(
            settings: effective,
            runtimeService: runtime
        )
    }

    func save() {
        try? storageService.save(settings, to: "settings.json")
    }
}
