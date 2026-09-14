import Foundation

@MainActor
final class GameService: ObservableObject {
    @Published private(set) var games: [Game] = []
    @Published private(set) var containers: [Container] = []

    private let storage: StorageService
    private let gamesFilename = "games.json"
    private let containersFilename = "containers.json"

    init(storage: StorageService) {
        self.storage = storage
        load()
    }

    // MARK: - Persistence

    func load() {
        games = storage.load([Game].self, from: gamesFilename) ?? []
        containers = storage.load([Container].self, from: containersFilename) ?? []
    }

    func save() {
        try? storage.save(games, to: gamesFilename)
    }

    func saveContainers() {
        try? storage.save(containers, to: containersFilename)
    }

    // MARK: - Game CRUD

    func addGame(_ game: Game) {
        games.append(game)
        save()
    }

    func updateGame(_ game: Game) {
        guard let index = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[index] = game
        save()
    }

    func deleteGame(id: UUID) {
        games.removeAll { $0.id == id }
        containers.removeAll { $0.gameID == id }
        save()
        saveContainers()
    }

    func game(withID id: UUID) -> Game? {
        games.first { $0.id == id }
    }

    func recordPlay(gameID: UUID) {
        guard let index = games.firstIndex(where: { $0.id == gameID }) else { return }
        games[index] = games[index].updated(lastPlayed: Date())
        save()
    }

    // MARK: - Container CRUD

    func addContainer(_ container: Container) {
        containers.append(container)
        saveContainers()

        if let index = games.firstIndex(where: { $0.id == container.gameID }) {
            games[index].containerID = container.id
            save()
        }
    }

    func updateContainer(_ container: Container) {
        guard let index = containers.firstIndex(where: { $0.id == container.id }) else { return }
        containers[index] = container
        saveContainers()
    }

    func container(for gameID: UUID) -> Container? {
        containers.first { $0.gameID == gameID }
    }

    func deleteContainer(id: UUID) {
        containers.removeAll { $0.id == id }
        saveContainers()
    }
}