import XCTest
@testable import GameHub

final class PersistenceTests: XCTestCase {

    private var storageDir: URL!
    private var storage: StorageService!

    private var uniqueBase: URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GameHubTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        storageDir = uniqueBase
        storage = StorageService(baseDirectory: storageDir)
        try? storage.ensureBaseStructure()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storageDir)
        try super.tearDownWithError()
    }

    func testGameRoundTripPreservesAllFields() throws {
        let url = storage.gamesDirectory.appendingPathComponent("UUID/Game.exe")
        let original = Game(
            title: "Portal 2",
            executableName: "portal2.exe",
            executableURL: url,
            executableSize: 12_345_678,
            lastPlayed: Date(timeIntervalSince1970: 1_700_000_000),
            dateAdded: Date(timeIntervalSince1970: 1_600_000_000),
            runtimeConfig: RuntimeConfig(
                windowsVersion: .windows11,
                dxvkEnabled: true,
                dxmtEnabled: true,
                mscvrtEnabled: false
            ),
            launchArguments: ["-windowed", "-novid"],
            isFavorite: true
        )

        try storage.save([original], to: "games.json")
        let loaded = try XCTUnwrap(storage.load([Game].self, from: "games.json"))

        XCTAssertEqual(loaded.count, 1)
        let game = loaded[0]
        XCTAssertEqual(game.id, original.id)
        XCTAssertEqual(game.title, "Portal 2")
        XCTAssertEqual(game.executableName, "portal2.exe")
        XCTAssertEqual(game.executableURL, url)
        XCTAssertEqual(game.executableSize, 12_345_678)
        XCTAssertEqual(game.lastPlayed, original.lastPlayed)
        XCTAssertEqual(game.dateAdded, original.dateAdded)
        XCTAssertEqual(game.runtimeConfig.windowsVersion, .windows11)
        XCTAssertEqual(game.runtimeConfig.dxvkEnabled, true)
        XCTAssertEqual(game.runtimeConfig.dxmtEnabled, true)
        XCTAssertEqual(game.runtimeConfig.mscvrtEnabled, false)
        XCTAssertEqual(game.launchArguments, ["-windowed", "-novid"])
        XCTAssertTrue(game.isFavorite)
    }

    func testGameServicePersistsAddsAndLoads() throws {
        let service = GameService(storage: storage)
        let game = Game(
            title: "Doom",
            executableName: "doom.exe",
            executableURL: URL(fileURLWithPath: "/tmp/doom.exe")
        )
        service.addGame(game)
        XCTAssertEqual(service.games.count, 1)

        let reloaded = GameService(storage: storage)
        XCTAssertEqual(reloaded.games.count, 1)
        XCTAssertEqual(reloaded.games.first?.title, "Doom")
    }

    func testContainerRoundTrip() throws {
        let gameID = UUID()
        let prefix = storage.containersDirectory
            .appendingPathComponent("abc/prefix", isDirectory: true)
        let container = Container(
            gameID: gameID,
            prefixLocation: prefix,
            windowsArchitecture: .x86_64,
            wineVersion: "madeira-97e2ce2",
            environmentVariables: ["WINEPREFIX": prefix.path, "WINEDEBUG": "-all"],
            status: .ready
        )

        try storage.save([container], to: "containers.json")
        let loaded = try XCTUnwrap(storage.load([Container].self, from: "containers.json"))

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].gameID, gameID)
        XCTAssertEqual(loaded[0].prefixLocation, prefix)
        XCTAssertEqual(loaded[0].windowsArchitecture, .x86_64)
        XCTAssertEqual(loaded[0].environmentVariables["WINEDEBUG"], "-all")
        XCTAssertEqual(loaded[0].status, .ready)
    }

    func testSettingsRoundTrip() throws {
        let settings = AppSettings(
            runtimeProviderID: "madeira",
            defaultWindowsArchitecture: .x86_64,
            requireContainerPerGame: true,
            showImportedOnly: false,
            autoCreateContainerOnImport: false,
            artworkAutoDownload: false,
            cacheArtworkLocally: true
        )

        try storage.save(settings, to: "settings.json")
        let loaded = try XCTUnwrap(storage.load(AppSettings.self, from: "settings.json"))
        XCTAssertEqual(loaded, settings)
        XCTAssertEqual(loaded.runtimeProviderID, "madeira")
        XCTAssertEqual(loaded.defaultWindowsArchitecture, .x86_64)
        XCTAssertFalse(loaded.autoCreateContainerOnImport)
    }

    func testCopyFileToLibraryStoresIntoManagedStorage() throws {
        let source = storageDir.appendingPathComponent("source.exe")
        try "fake-exe".data(using: .utf8)!.write(to: source)

        let gameID = UUID()
        let dest = try storage.copyFileToLibrary(sourceURL: source, gameID: gameID)

        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
        XCTAssertEqual(dest.deletingLastPathComponent().lastPathComponent, gameID.uuidString)
        XCTAssertEqual(dest.lastPathComponent, "source.exe")
    }
}