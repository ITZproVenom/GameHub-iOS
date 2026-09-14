import Foundation

enum LogLevel: String, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

struct LogEntry: Identifiable, Sendable {
    let id: UUID = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
}

actor LogStore {
    private var entries: [LogEntry] = []
    private let maxEntries: Int

    init(maxEntries: Int = 2000) {
        self.maxEntries = maxEntries
    }

    func append(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func all() -> [LogEntry] {
        entries
    }

    func clear() {
        entries.removeAll()
    }
}

@MainActor
final class LogService: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []

    private let store: LogStore
    private static let persistenceFilename = "logs.json"

    init(store: LogStore = LogStore()) {
        self.store = store
        loadPersisted()
    }

    func log(_ message: String, level: LogLevel = .info, category: String = "App") {
        let entry = LogEntry(timestamp: Date(), level: level, category: category, message: message)
        entries.append(entry)
        persist()

        #if DEBUG
        let prefix = "[\(level.rawValue)][\(category)] "
        NSLog("%@%@", prefix, message)
        #endif
    }

    func debug(_ message: String, category: String = "App") {
        log(message, level: .debug, category: category)
    }

    func info(_ message: String, category: String = "App") {
        log(message, level: .info, category: category)
    }

    func warning(_ message: String, category: String = "App") {
        log(message, level: .warning, category: category)
    }

    func error(_ message: String, category: String = "App") {
        log(message, level: .error, category: category)
    }

    func clear() {
        entries.removeAll()
        try? FileManager.default.removeItem(
            at: persistenceURL()
        )
    }

    func entries(of level: LogLevel) -> [LogEntry] {
        entries.filter { $0.level == level }
    }

    func exportText() -> String {
        let formatter = ISO8601DateFormatter()
        return entries.map { entry in
            "[\(formatter.string(from: entry.timestamp))] \(entry.level.rawValue) [\(entry.category)] \(entry.message)"
        }.joined(separator: "\n")
    }

    // MARK: - Persistence

    private func persistenceURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent(GameHubConstants.storageDirectory, isDirectory: true)
            .appendingPathComponent(Self.persistenceFilename)
    }

    private func persist() {
        struct Persistable: Codable {
            let timestamp: Date
            let level: String
            let category: String
            let message: String
        }

        let data = entries.map {
            Persistable(timestamp: $0.timestamp, level: $0.level.rawValue, category: $0.category, message: $0.message)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let encoded = try? encoder.encode(data) else { return }
        try? encoded.write(to: persistenceURL(), options: .atomic)
    }

    private func loadPersisted() {
        struct Persistable: Decodable {
            let timestamp: Date
            let level: String
            let category: String
            let message: String
        }

        guard let data = try? Data(contentsOf: persistenceURL()) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let decoded = try? decoder.decode([Persistable].self, from: data) else { return }

        entries = decoded.compactMap { item in
            guard let level = LogLevel(rawValue: item.level) else { return nil }
            return LogEntry(timestamp: item.timestamp, level: level, category: item.category, message: item.message)
        }
    }
}