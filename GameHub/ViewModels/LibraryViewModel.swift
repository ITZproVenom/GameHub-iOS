import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var searchText = ""
    @Published var sortOrder: LibrarySort = .dateAdded
    @Published var showFavoritesOnly = false
    @Published var selectedGame: Game?
    @Published var showingImport = false
    @Published var showingSettings = false
    @Published var runtimeStatus: RuntimeStatus?
    @Published var activeContainerIDs: Set<UUID> = []
    @Published var errorMessage: String?

    private var artworkCache: [UUID: UIImage] = [:]
    private let gameService: GameService
    private let containerService: ContainerService
    private let runtimeService: RuntimeService
    public let storageService: StorageService

    init(
        gameService: GameService,
        containerService: ContainerService,
        runtimeService: RuntimeService,
        storageService: StorageService
    ) {
        self.gameService = gameService
        self.containerService = containerService
        self.runtimeService = runtimeService
        self.storageService = storageService
        self.games = gameService.games
        self.activeContainerIDs = Set(containerService.containers.map(\.id))
    }

    var filteredGames: [Game] {
        var result = games

        if showFavoritesOnly {
            result = result.filter(\.isFavorite)
        }

        if !searchText.isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            result = result.filter { game in
                game.title.lowercased().contains(query)
                    || game.executableName.lowercased().contains(query)
            }
        }

        switch sortOrder {
        case .dateAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .title:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .lastPlayed:
            result.sort { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        case .size:
            result.sort { $0.executableSize > $1.executableSize }
        }

        return result
    }

    var isEmpty: Bool {
        games.isEmpty
    }

    var libraryHeaderText: String {
        let count = filteredGames.count
        if count == 1 {
            return "1 Game"
        }
        return "\(count) Games"
    }

    func container(for game: Game) -> Container? {
        containerService.container(for: game.id)
    }

    func artwork(for game: Game) -> UIImage? {
        if let cached = artworkCache[game.id] {
            return cached
        }
        guard let filename = game.artworkFileName else { return nil }
        let url = storageService.artworkURL(for: filename)
        guard storageService.fileExists(at: url),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        artworkCache[game.id] = image
        return image
    }

    func activeContainer(for game: Game) -> Container? {
        containerService.container(for: game.id)
    }

    func reloadData() {
        games = gameService.games
    }

    func play(game: Game) {
        Task {
            guard let container = containerService.container(for: game.id) else {
                errorMessage = ContainerError.notFound.localizedDescription
                return
            }

            guard let executableFile = executableURL(for: game) else {
                errorMessage = "Executable file missing for \(game.title)"
                return
            }

            let result = await runtimeService.launchGame(
                game: game,
                executableURL: executableFile,
                prefixURL: container.prefixLocation,
                environment: container.environmentVariables
            )

            switch result {
            case .success:
                gameService.recordPlay(gameID: game.id)
                reloadData()
            case .runtimeNotInstalled:
                let providerName = (await runtimeService.activeProvider)?.name ?? "runtime"
                errorMessage = "The \(providerName) runtime is not installed."
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
    }

    func refreshRuntimeStatus() {
        Task {
            let statuses = await runtimeService.currentStatus()
            runtimeStatus = statuses.first
        }
    }

    func deleteGame(_ game: Game) {
        gameService.deleteGame(id: game.id)
        reloadData()
    }

    func toggleFavorite(_ game: Game) {
        var updated = game
        updated.isFavorite.toggle()
        gameService.updateGame(updated)
        reloadData()
    }

    private func executableURL(for game: Game) -> URL? {
        if storageService.fileExists(at: game.executableURL) {
            return game.executableURL
        }
        return nil
    }
}