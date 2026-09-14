import XCTest
@testable import GameHub

final class SettingsTests: XCTestCase {

    private var storageDir: URL!
    private var storage: StorageService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GameHubSettingsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageDir = dir
        storage = StorageService(baseDirectory: dir)
        try? storage.ensureBaseStructure()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storageDir)
        try super.tearDownWithError()
    }

    func testDefaultSettingsAreSane() {
        let defaults = AppSettings.default
        XCTAssertEqual(defaults.runtimeProviderID, "madeira")
        XCTAssertEqual(defaults.defaultWindowsArchitecture, .x86_64)
        XCTAssertFalse(defaults.requireContainerPerGame)
        XCTAssertFalse(defaults.showImportedOnly)
        XCTAssertTrue(defaults.autoCreateContainerOnImport)
        XCTAssertTrue(defaults.artworkAutoDownload)
        XCTAssertTrue(defaults.cacheArtworkLocally)
    }

    func testSettingsPersistToStorage() throws {
        var settings = AppSettings.default
        settings.defaultWindowsArchitecture = .arm64
        settings.autoCreateContainerOnImport = false

        try storage.save(settings, to: "settings.json")
        let loaded = try XCTUnwrap(storage.load(AppSettings.self, from: "settings.json"))

        XCTAssertEqual(loaded.defaultWindowsArchitecture, .arm64)
        XCTAssertFalse(loaded.autoCreateContainerOnImport)
    }

    func testRuntimeConfigVersionRadix() {
        let config = RuntimeConfig(
            windowsVersion: .win10,
            dxvkEnabled: true,
            dxmtEnabled: true,
            mscvrtEnabled: true
        )
        XCTAssertEqual(config.windowsVersion.displayName, "Windows 10")
    }
}