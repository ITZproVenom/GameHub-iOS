import Foundation

enum ContainerError: LocalizedError, Sendable {
    case alreadyExists
    case notFound
    case createFailed(String)
    case deleteFailed(String)
    case resetFailed(String)
    case statusCheckFailed(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .alreadyExists: return "A container already exists for this game."
        case .notFound: return "Container not found."
        case .createFailed(let msg): return "Failed to create container: \(msg)"
        case .deleteFailed(let msg): return "Failed to delete container: \(msg)"
        case .resetFailed(let msg): return "Failed to reset container: \(msg)"
        case .statusCheckFailed(let msg): return "Failed to check container status: \(msg)"
        case .unsupported(let msg): return msg
        }
    }
}

@MainActor
final class ContainerService: ObservableObject {
    @Published private(set) var containers: [Container] = []

    private let storage: StorageService
    private let fileManager: FileManager = .default
    private let containersFilename = "containers.json"

    init(storage: StorageService) {
        self.storage = storage
        loadContainers()
    }

    // MARK: - Container Management

    func createContainer(for game: Game, architecture: WindowsArchitecture) async throws -> Container {
        if containers.contains(where: { $0.gameID == game.id }) {
            throw ContainerError.alreadyExists
        }

        let containerID = UUID()
        let prefixLocation: URL

        do {
            prefixLocation = try storage.containerDirectory(for: containerID)
                .appendingPathComponent("prefix", isDirectory: true)
            try fileManager.createDirectory(at: prefixLocation, withIntermediateDirectories: true)
        } catch {
            throw ContainerError.createFailed(error.localizedDescription)
        }

        // Seed the Wine prefix from the bundled template (PE sysroots + registry)
        seedPrefixIfNeeded(at: prefixLocation)

        var container = Container(
            id: containerID,
            gameID: game.id,
            prefixLocation: prefixLocation,
            windowsArchitecture: architecture,
            status: .ready
        )

        container.createdDate = Date()
        container.modifiedDate = Date()

        containers.append(container)
        save()

        return container
    }

    /// Extract Runtime/prefix-template.tar.gz into the container prefix directory.
    private func seedPrefixIfNeeded(at prefixLocation: URL) {
        let stamp = prefixLocation.appendingPathComponent(".update-timestamp")
        if fileManager.fileExists(atPath: stamp.path) {
            return
        }

        // Prefer force-embedded Runtime/ inside the .app
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "prefix-template", withExtension: "tar.gz", subdirectory: "Runtime"),
            Bundle.main.resourceURL?.appendingPathComponent("Runtime/prefix-template.tar.gz"),
            Bundle.main.url(forResource: "prefix-template", withExtension: "tar.gz"),
        ]

        guard let tgz = candidates.compactMap({ $0 }).first(where: {
            fileManager.fileExists(atPath: $0.path)
        }) else {
            // Create minimal skeleton so the directory is usable
            try? fileManager.createDirectory(
                at: prefixLocation.appendingPathComponent("drive_c", isDirectory: true),
                withIntermediateDirectories: true
            )
            return
        }

        let rc = madeira_extract_prefix_tgz(tgz.path, prefixLocation.path)
        if rc == 0 {
            try? "seeded".write(to: stamp, atomically: true, encoding: .utf8)
        } else {
            // Still create drive_c so launch path has somewhere to work
            try? fileManager.createDirectory(
                at: prefixLocation.appendingPathComponent("drive_c", isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        // dosdevices/c: -> ../drive_c
        let dosdev = prefixLocation.appendingPathComponent("dosdevices", isDirectory: true)
        try? fileManager.createDirectory(at: dosdev, withIntermediateDirectories: true)
        let cLink = dosdev.appendingPathComponent("c:")
        try? fileManager.removeItem(at: cLink)
        try? fileManager.createSymbolicLink(at: cLink, withDestinationURL: URL(fileURLWithPath: "../drive_c"))
    }

    func loadContainer(withID id: UUID) -> Container? {
        containers.first { $0.id == id }
    }

    func container(for gameID: UUID) -> Container? {
        containers.first { $0.gameID == gameID }
    }

    func deleteContainer(withID id: UUID) async throws {
        guard let index = containers.firstIndex(where: { $0.id == id }) else {
            throw ContainerError.notFound
        }

        let container = containers[index]
        try? fileManager.removeItem(at: container.prefixLocation)

        containers.remove(at: index)
        save()
    }

    func resetContainer(withID id: UUID) async throws {
        guard let index = containers.firstIndex(where: { $0.id == id }) else {
            throw ContainerError.notFound
        }

        var container = containers[index]
        container.status = .resetting
        containers[index] = container

        try? fileManager.removeItem(at: container.prefixLocation)
        try fileManager.createDirectory(at: container.prefixLocation, withIntermediateDirectories: true)
        seedPrefixIfNeeded(at: container.prefixLocation)

        container.status = .ready
        container.lastError = nil
        container.modifiedDate = Date()
        containers[index] = container
        save()
    }

    func checkContainerState(withID id: UUID) async -> ContainerStatus {
        guard let container = containers.first(where: { $0.id == id }) else {
            return .notCreated
        }

        let prefixPath = container.prefixLocation
        guard fileManager.fileExists(atPath: prefixPath.path) else {
            updateContainer(container.with(status: .notCreated, lastError: nil))
            return .notCreated
        }

        let driveC = prefixPath.appendingPathComponent("drive_c")
        let status: ContainerStatus = fileManager.fileExists(atPath: driveC.path) ? .ready : .creating
        updateContainer(container.with(status: status, lastError: nil))
        return status
    }

    func updateContainer(_ container: Container) {
        guard let index = containers.firstIndex(where: { $0.id == container.id }) else { return }
        containers[index] = container.with(modifiedAt: Date())
        save()
    }

    func setContainerStatus(_ status: ContainerStatus, forID id: UUID, lastError: String? = nil) {
        guard let index = containers.firstIndex(where: { $0.id == id }) else { return }
        containers[index].status = status
        containers[index].lastError = lastError
        save()
    }

    // MARK: - Persistence

    func save() {
        try? storage.save(containers, to: containersFilename)
    }

    func loadContainers() {
        containers = storage.load([Container].self, from: containersFilename) ?? []
    }
}

private extension Container {
    func with(status newStatus: ContainerStatus, lastError newLastError: String?) -> Container {
        var copy = self
        copy.status = newStatus
        copy.lastError = newLastError
        return copy
    }

    func with(modifiedAt date: Date) -> Container {
        var copy = self
        copy.modifiedDate = date
        return copy
    }
}
