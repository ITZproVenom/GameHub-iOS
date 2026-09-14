import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ImportError: LocalizedError, Sendable {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var isImporting = false
    @Published var importError: String?
    @Published var importedGame: Game?
    @Published var discoveredExecutables: [URL] = []

    private let gameService: GameService
    private let storageService: StorageService
    private let containerService: ContainerService

    init(
        gameService: GameService,
        storageService: StorageService,
        containerService: ContainerService
    ) {
        self.gameService = gameService
        self.storageService = storageService
        self.containerService = containerService
    }

    var supportedContentTypes: [UTType] {
        var types: [UTType] = []
        types.append(UTType(filenameExtension: "exe") ?? .exe)
        types.append(UTType(filenameExtension: "msi") ?? .data)
        types.append(UTType(filenameExtension: "bat") ?? .data)
        types.append(UTType(filenameExtension: "cmd") ?? .data)
        return types
    }

    // MARK: - Import

    func importExecutable(from sourceURL: URL) async {
        isImporting = true
        defer { isImporting = false }

        let executableName = sourceURL.lastPathComponent
        guard sourceURL.isExecutable else {
            importError = ImportError("Only .exe, .msi, .bat and .cmd files can be imported as Windows executables.").localizedDescription
            return
        }

        let securityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if securityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let gameID = UUID()
            let destinationURL = try storageService.copyFileToLibrary(sourceURL: sourceURL, gameID: gameID)
            let size = fileSize(at: destinationURL)

            let title = destinationURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .truncatedToWordBoundary(limit: 60)

            var game = Game(
                title: title,
                executableName: executableName,
                executableURL: destinationURL,
                executableSize: size,
                dateAdded: Date(),
                dateModified: Date()
            )

            gameService.addGame(game)

            if let created = try? await containerService.createContainer(for: game, architecture: .x86_64) {
                game.containerID = created.id
                gameService.updateGame(game)
            }

            importedGame = game
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - Executable Discovery

    func discoverExecutables() async {
        discoveredExecutables = []
        let gamesDirectory = storageService.gamesDirectory

        let folders = storageService.contentsOfDirectory(at: gamesDirectory)
        for folder in folders where folder.hasDirectoryPath {
            let content = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            discoveredExecutables.append(contentsOf: content.filter { $0.isExecutable })
        }
    }

    private func fileSize(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }
}

extension String {
    func truncatedToWordBoundary(limit: Int) -> String {
        guard count > limit else { return self }
        let prefix = String(prefix(limit)).trimmingCharacters(in: .whitespaces)
        return prefix + "…"
    }
}