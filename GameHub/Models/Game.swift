import Foundation

struct Game: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var executableName: String
    var executableURL: URL
    var executableSize: Int64

    var artworkFileName: String?
    var lastPlayed: Date?
    var dateAdded: Date
    var dateModified: Date

    var containerID: UUID?
    var runtimeConfig: RuntimeConfig
    var launchArguments: [String]
    var workingDirectory: URL?

    var isFavorite: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        executableName: String,
        executableURL: URL,
        executableSize: Int64 = 0,
        artworkFileName: String? = nil,
        lastPlayed: Date? = nil,
        dateAdded: Date = Date(),
        dateModified: Date = Date(),
        containerID: UUID? = nil,
        runtimeConfig: RuntimeConfig = RuntimeConfig.default,
        launchArguments: [String] = [],
        workingDirectory: URL? = nil,
        isFavorite: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.executableName = executableName
        self.executableURL = executableURL
        self.executableSize = executableSize
        self.artworkFileName = artworkFileName
        self.lastPlayed = lastPlayed
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.containerID = containerID
        self.runtimeConfig = runtimeConfig
        self.launchArguments = launchArguments
        self.workingDirectory = workingDirectory
        self.isFavorite = isFavorite
        self.sortOrder = sortOrder
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: executableSize, countStyle: .file)
    }

    func updated(playCount _: Int = 0, lastPlayed date: Date = Date()) -> Game {
        var copy = self
        copy.lastPlayed = date
        copy.dateModified = date
        return copy
    }
}

enum LibrarySort: String, CaseIterable, Identifiable, Sendable {
    case dateAdded
    case title
    case lastPlayed
    case size

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateAdded: return "Date Added"
        case .title: return "Title"
        case .lastPlayed: return "Last Played"
        case .size: return "Size"
        }
    }
}