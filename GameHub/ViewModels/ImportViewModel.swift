import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ImportError: LocalizedError, Sendable {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

extension UTType {
    /// Windows PE executable. Declared so the document picker can surface .exe files on device.
    static var windowsExecutable: UTType {
        UTType(exportedAs: "com.microsoft.windows-executable", conformingTo: .data)
    }

    static var windowsInstaller: UTType {
        UTType(exportedAs: "com.microsoft.msi-installer", conformingTo: .data)
    }
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

    /// Content types accepted by the system document picker.
    /// Include both custom types and broad fallbacks so .exe is visible on real devices.
    var supportedContentTypes: [UTType] {
        var types: [UTType] = [
            .windowsExecutable,
            .windowsInstaller,
            .data,          // catch-all so Files shows unknown binary types
            .item,
        ]
        // Prefer filename-extension types when the system knows them
        if let exe = UTType(filenameExtension: "exe") { types.insert(exe, at: 0) }
        if let msi = UTType(filenameExtension: "msi") { types.insert(msi, at: 0) }
        if let bat = UTType(filenameExtension: "bat") { types.insert(bat, at: 0) }
        if let cmd = UTType(filenameExtension: "cmd") { types.insert(cmd, at: 0) }
        return types
    }

    // MARK: - Import

    func importExecutable(from sourceURL: URL) async {
        isImporting = true
        importError = nil
        defer { isImporting = false }

        let executableName = sourceURL.lastPathComponent

        // 1. Extension gate (pathExtension works for security-scoped URLs)
        guard sourceURL.isExecutable else {
            importError = "Only .exe, .msi, .bat and .cmd files can be imported. Selected: \(executableName)"
            return
        }

        // 2. Security-scoped access — required for Files / iCloud / external storage
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        // 3. Validate the file is actually readable while the scope is held
        do {
            let values = try sourceURL.resourceValues(forKeys: [
                .isRegularFileKey,
                .fileSizeKey,
                .isReadableKey,
            ])
            guard values.isRegularFile == true else {
                importError = "Selected item is not a regular file."
                return
            }
            guard (values.isReadable ?? false) || didStartAccess else {
                importError = "Cannot read the selected file. Check permissions."
                return
            }
            let size = Int64(values.fileSize ?? 0)
            if size <= 0 {
                // Fallback: try opening
                let handle = try FileHandle(forReadingFrom: sourceURL)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: 64)
                if data == nil || data!.isEmpty {
                    importError = "Selected file is empty or unreadable."
                    return
                }
            }
        } catch {
            importError = "Cannot access selected file: \(error.localizedDescription)"
            return
        }

        // 4. Copy into the app sandbox (must happen while security scope is active)
        do {
            let gameID = UUID()
            let destinationURL = try storageService.copyFileToLibrary(
                sourceURL: sourceURL,
                gameID: gameID
            )

            // Verify the copy landed and is non-zero
            let attrs = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let size = (attrs[.size] as? Int64) ?? 0
            guard size > 0 else {
                importError = "Imported file is empty after copy."
                try? FileManager.default.removeItem(at: destinationURL)
                return
            }

            let title = destinationURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .truncatedToWordBoundary(limit: 60)

            var game = Game(
                id: gameID,
                title: title,
                executableName: executableName,
                executableURL: destinationURL,
                executableSize: size,
                dateAdded: Date(),
                dateModified: Date()
            )

            gameService.addGame(game)

            // Create a container / prefix for this game (best-effort)
            if let created = try? await containerService.createContainer(for: game, architecture: .x86_64) {
                game.containerID = created.id
                gameService.updateGame(game)
            }

            importedGame = game
        } catch {
            importError = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Executable Discovery

    func discoverExecutables() async {
        discoveredExecutables = []
        let gamesDirectory = storageService.gamesDirectory

        let folders = storageService.contentsOfDirectory(at: gamesDirectory)
        for folder in folders where folder.hasDirectoryPath {
            let content = (try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey]
            )) ?? []
            discoveredExecutables.append(contentsOf: content.filter { $0.isExecutable })
        }
    }
}

extension String {
    func truncatedToWordBoundary(limit: Int) -> String {
        guard count > limit else { return self }
        let prefix = String(prefix(limit)).trimmingCharacters(in: .whitespaces)
        return prefix + "…"
    }
}
