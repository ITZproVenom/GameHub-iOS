import Foundation
import SwiftUI

@MainActor
final class GameDetailViewModel: ObservableObject {
    @Published var game: Game
    @Published var container: Container?
    @Published var containerStatus: ContainerStatus = .notCreated
    @Published var isEditingTitle = false
    @Published var isEditingRuntime = false
    @Published var artworkImage: UIImage?
    @Published var artworkLoading = false
    @Published var isLaunching = false
    @Published var isPlaying = false
    @Published var errorMessage: String?
    @Published var jitReady: Bool = false

    private let gameService: GameService
    private let containerService: ContainerService
    private let runtimeService: RuntimeService
    private let storageService: StorageService

    init(
        game: Game,
        gameService: GameService,
        containerService: ContainerService,
        runtimeService: RuntimeService,
        storageService: StorageService
    ) {
        self.game = game
        self.gameService = gameService
        self.containerService = containerService
        self.runtimeService = runtimeService
        self.storageService = storageService
        self.container = containerService.container(for: game.id)
        refreshJITStatus()
        Task { await refreshContainerStatus() }
        Task { loadArtwork() }
    }

    var executableExists: Bool {
        storageService.fileExists(at: game.executableURL)
    }

    var executablePathString: String {
        game.executableURL.path
    }

    var formattedExecutableSize: String {
        ByteCountFormatter.string(fromByteCount: game.executableSize, countStyle: .file)
    }

    var jitStatusText: String {
        if jitReady {
            return "JIT ready — full FEX path available"
        }
        return "JIT not enabled — library & prefixes work; execution needs StikDebug / StikJIT"
    }

    func refreshJITStatus() {
        jitReady = MadeiraBootSequence.isJITReady()
    }

    func updateTitle(_ newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != game.title else { return }
        game.title = trimmed
        game.dateModified = Date()
        gameService.updateGame(game)
    }

    func stopSession() async {
        isPlaying = false
        MetalHostView.shared.uninstall()
        await runtimeService.stopAll()
    }

    func launch() async {
        isLaunching = true
        errorMessage = nil
        defer { isLaunching = false }

        refreshJITStatus()

        guard let container = containerService.container(for: game.id) else {
            errorMessage = "Create a container for this game before launching."
            return
        }

        guard executableExists else {
            errorMessage = "The executable for this game is missing."
            return
        }

        let result = await runtimeService.launchGame(
            game: game,
            executableURL: game.executableURL,
            prefixURL: container.prefixLocation,
            environment: container.environmentVariables
        )

        switch result {
        case .success, .successLaunched:
            gameService.recordPlay(gameID: game.id)
            game.lastPlayed = Date()
            isPlaying = true
        case .runtimeNotInstalled:
            errorMessage = "The runtime is not installed."
        case .binaryMissing(let msg):
            errorMessage = msg
        case .entitlementRequired(let msg):
            errorMessage = msg
        case .unsupported(let msg):
            errorMessage = msg
        case .error(let msg):
            errorMessage = msg
        }
    }

    func createContainer() {
        Task {
            do {
                let container = try await containerService.createContainer(
                    for: game,
                    architecture: .x86_64
                )
                self.container = container
                game.containerID = container.id
                gameService.updateGame(game)
                await refreshContainerStatus()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteContainer() {
        guard let containerID = container?.id else { return }
        Task {
            do {
                try await containerService.deleteContainer(withID: containerID)
                self.container = nil
                game.containerID = nil
                gameService.updateGame(game)
                await refreshContainerStatus()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func resetContainer() {
        guard let containerID = container?.id else { return }
        Task {
            do {
                try await containerService.resetContainer(withID: containerID)
                await refreshContainerStatus()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func refreshContainerStatus() async {
        guard let containerID = container?.id else {
            containerStatus = .notCreated
            return
        }
        containerStatus = await containerService.checkContainerState(withID: containerID)
    }

    func loadArtwork() {
        guard let artworkFileName = game.artworkFileName else { return }
        let artworkURL = storageService.artworkURL(for: artworkFileName)
        guard storageService.fileExists(at: artworkURL) else { return }
        artworkLoading = true
        Task {
            artworkImage = UIImage(contentsOfFile: artworkURL.path)
            artworkLoading = false
        }
    }
}
