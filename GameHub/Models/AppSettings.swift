import Foundation

struct AppSettings: Codable, Hashable, Sendable {
    var runtimeProviderID: String
    var defaultWindowsArchitecture: WindowsArchitecture
    var requireContainerPerGame: Bool
    var showImportedOnly: Bool
    var autoCreateContainerOnImport: Bool
    var artworkAutoDownload: Bool
    var cacheArtworkLocally: Bool

    static let `default` = AppSettings(
        runtimeProviderID: "madeira",
        defaultWindowsArchitecture: .x86_64,
        requireContainerPerGame: false,
        showImportedOnly: false,
        autoCreateContainerOnImport: true,
        artworkAutoDownload: true,
        cacheArtworkLocally: true
    )
}