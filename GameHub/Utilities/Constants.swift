import Foundation

enum GameHubConstants {
    static let bundleID = "com.gamehub.ios"
    static let appName = "GameHub"
    static let storageDirectory = "GameHubData"
    static let gamesDirectory = "Games"
    static let containersDirectory = "Containers"
    static let artworkDirectory = "Artwork"
    static let cacheDirectory = "Cache"

    static let defaultExecutableExtensions = ["exe", "bat", "cmd", "msi"]

    static let maxArtworkWidth: CGFloat = 400
    static let maxArtworkHeight: CGFloat = 600

    static let madeiraProjectURL = "https://github.com/willfaust/Madeira"
    static let madeiraPinnedCommit = "97e2ce26e6dc9e4a38976f3b5deb9272d64558eb"
    static let madeiraDefaultBranch = "main"
    static let madeiraLicense = "GPL-3.0-or-later"
}