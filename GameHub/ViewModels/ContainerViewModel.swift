import Foundation
import SwiftUI

@MainActor
final class ContainerViewModel: ObservableObject {
    @Published var container: Container
    @Published var isDeleting = false
    @Published var isResetting = false
    @Published var errorMessage: String?

    private let containerService: ContainerService
    private let gameService: GameService

    init(container: Container, containerService: ContainerService, gameService: GameService) {
        self.container = container
        self.containerService = containerService
        self.gameService = gameService
    }

    var game: Game? {
        gameService.game(withID: container.gameID)
    }

    var statusTitle: String {
        container.status.title
    }

    var statusColor: Color {
        switch container.status {
        case .notCreated: return .gray
        case .creating: return .blue
        case .ready: return .green
        case .launching: return .orange
        case .running: return .green
        case .error: return .red
        case .resetting: return .orange
        case .deleted: return .gray
        }
    }

    var createdDateDescription: String {
        container.createdDate.shortDescription
    }

    var modifiedDateDescription: String {
        container.modifiedDate.shortDescription
    }

    func updateArchitecture(_ architecture: WindowsArchitecture) {
        container.windowsArchitecture = architecture
        containerService.updateContainer(container)
    }

    func toggleDXVK(enabled: Bool) {
        container.dxvkEnabled = enabled
        containerService.updateContainer(container)
    }

    func toggleDXMT(enabled: Bool) {
        container.dxmtEnabled = enabled
        containerService.updateContainer(container)
    }

    func setEnvironmentVariable(key: String, value: String) {
        container.environmentVariables[key] = value
        containerService.updateContainer(container)
    }

    func removeEnvironmentVariable(key: String) {
        container.environmentVariables.removeValue(forKey: key)
        containerService.updateContainer(container)
    }

    func updateWineVersion(_ version: String) {
        container.wineVersion = version
        containerService.updateContainer(container)
    }

    func launch() -> LaunchResult {
        .unsupported("Container launch requires the Madeira runtime binaries.")
    }

    func deleteContainer() {
        isDeleting = true
        Task {
            do {
                try await containerService.deleteContainer(withID: container.id)
                // Container removed; caller should dismiss.
            } catch {
                errorMessage = error.localizedDescription
            }
            isDeleting = false
        }
    }

    func resetContainer() {
        isResetting = true
        Task {
            do {
                try await containerService.resetContainer(withID: container.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            isResetting = false
        }
    }
}