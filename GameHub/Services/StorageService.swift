import Foundation

enum StorageError: LocalizedError, Sendable {
    case directoryCreationFailed(String)
    case encodingFailed(String)
    case decodingFailed(String)
    case fileNotFound(String)
    case fileCopyFailed(String)
    case quotaExceeded
    case unreadableSource(String)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let msg): return "Failed to create directory: \(msg)"
        case .encodingFailed(let msg): return "Failed to encode data: \(msg)"
        case .decodingFailed(let msg): return "Failed to decode data: \(msg)"
        case .fileNotFound(let msg): return "File not found: \(msg)"
        case .fileCopyFailed(let msg): return "Failed to copy file: \(msg)"
        case .quotaExceeded: return "Storage quota exceeded"
        case .unreadableSource(let msg): return "Cannot read source file: \(msg)"
        }
    }
}

final class StorageService: @unchecked Sendable {
    private let baseDirectory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager

        let resolved: URL
        if let baseDirectory {
            resolved = baseDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            resolved = appSupport.appendingPathComponent(GameHubConstants.storageDirectory, isDirectory: true)
        }
        self.baseDirectory = resolved

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - Directory Access

    var gamesDirectory: URL {
        baseDirectory.appendingPathComponent(GameHubConstants.gamesDirectory, isDirectory: true)
    }

    var containersDirectory: URL {
        baseDirectory.appendingPathComponent(GameHubConstants.containersDirectory, isDirectory: true)
    }

    var artworkDirectory: URL {
        baseDirectory.appendingPathComponent(GameHubConstants.artworkDirectory, isDirectory: true)
    }

    func ensureBaseStructure() throws {
        let dirs = [baseDirectory, gamesDirectory, containersDirectory, artworkDirectory]
        for dir in dirs {
            if !fileManager.fileExists(atPath: dir.path) {
                do {
                    try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
                } catch {
                    throw StorageError.directoryCreationFailed(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Generic Persistence

    func save<T: Encodable>(_ object: T, to filename: String, in subdirectory: String? = nil) throws {
        let directory = subdirectory.map {
            baseDirectory.appendingPathComponent($0, isDirectory: true)
        } ?? baseDirectory

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let fileURL = directory.appendingPathComponent(filename)
        let data: Data
        do {
            data = try encoder.encode(object)
        } catch {
            throw StorageError.encodingFailed(error.localizedDescription)
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw StorageError.fileCopyFailed(error.localizedDescription)
        }
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String, in subdirectory: String? = nil) -> T? {
        let directory = subdirectory.map {
            baseDirectory.appendingPathComponent($0, isDirectory: true)
        } ?? baseDirectory

        let fileURL = directory.appendingPathComponent(filename)

        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? decoder.decode(type, from: data)
    }

    func delete(_ filename: String, from subdirectory: String? = nil) throws {
        let directory = subdirectory.map {
            baseDirectory.appendingPathComponent($0, isDirectory: true)
        } ?? baseDirectory

        let fileURL = directory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }

        try fileManager.removeItem(at: fileURL)
    }

    // MARK: - File Operations

    /// Copy a user-selected file (often security-scoped from the document picker)
    /// into the app's Games library. Preserves the original filename, including
    /// spaces and non-ASCII characters. Caller must hold the security scope
    /// for `sourceURL` while this method runs.
    func copyFileToLibrary(sourceURL: URL, gameID: UUID) throws -> URL {
        try ensureBaseStructure()

        let gameDir = gamesDirectory.appendingPathComponent(gameID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: gameDir, withIntermediateDirectories: true)

        // Preserve original filename (spaces, unicode, etc.)
        let originalName = sourceURL.lastPathComponent
        guard !originalName.isEmpty else {
            throw StorageError.fileCopyFailed("Source has empty filename")
        }

        let destURL = gameDir.appendingPathComponent(originalName)

        if fileManager.fileExists(atPath: destURL.path) {
            try fileManager.removeItem(at: destURL)
        }

        // Prefer coordinated / streaming copy so large .exe files and
        // security-scoped providers (iCloud, Files providers) work reliably.
        var copyError: Error?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: nil) { readableURL in
            do {
                // First try native copy (fast path when both sides are local)
                try self.fileManager.copyItem(at: readableURL, to: destURL)
            } catch {
                // Fallback: read all data then write (works across providers)
                do {
                    let data = try Data(contentsOf: readableURL, options: [.mappedIfSafe])
                    try data.write(to: destURL, options: .atomic)
                } catch {
                    copyError = error
                }
            }
        }

        if let copyError {
            throw StorageError.fileCopyFailed(copyError.localizedDescription)
        }

        guard fileManager.fileExists(atPath: destURL.path) else {
            throw StorageError.fileCopyFailed("Destination missing after copy")
        }

        return destURL
    }

    func containerDirectory(for containerID: UUID) throws -> URL {
        let dir = containersDirectory.appendingPathComponent(containerID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func saveArtwork(_ data: Data, filename: String) throws -> URL {
        try ensureBaseStructure()
        let fileURL = artworkDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }

    func artworkURL(for filename: String) -> URL {
        artworkDirectory.appendingPathComponent(filename)
    }

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func contentsOfDirectory(at directory: URL) -> [URL] {
        (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }
}
