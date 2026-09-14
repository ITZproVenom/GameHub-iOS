import XCTest
@testable import GameHub

final class ImportValidationTests: XCTestCase {

    private var storageDir: URL!
    private var storage: StorageService!

    private var uniqueBase: URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GameHubImportTests-\(UUID().uuidString)", isDirectory: true)
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

    func testValidExecutableExtensionsAccepted() {
        XCTAssertTrue("game.exe".isValidExecutableName)
        XCTAssertTrue("setup.msi".isValidExecutableName)
        XCTAssertTrue("launcher.bat".isValidExecutableName)
        XCTAssertTrue("run.cmd".isValidExecutableName)
    }

    func testInvalidExtensionsRejected() {
        XCTAssertFalse("image.png".isValidExecutableName)
        XCTAssertFalse("document.pdf".isValidExecutableName)
        XCTAssertFalse("archive.zip".isValidExecutableName)
        XCTAssertFalse("game.EXE.txt".isValidExecutableName)
    }

    func testURLExecutableDetection() {
        XCTAssertTrue(URL(fileURLWithPath: "/Games/foo.exe").isExecutable)
        XCTAssertFalse(URL(fileURLWithPath: "/Games/foo.jpg").isExecutable)
    }

    func testImportCreatesGameRecordAndCopiesFile() async throws {
        let gameService = GameService(storage: storage)
        let containerService = ContainerService(storage: storage)
        let viewModel = ImportViewModel(
            gameService: gameService,
            storageService: storage,
            containerService: containerService
        )

        let source = storageDir.appendingPathComponent("HalfLife.exe")
        try "mock-windows-binary".data(using: .utf8)!.write(to: source)

        await viewModel.importExecutable(from: source)

        guard let imported = viewModel.importedGame else {
            XCTFail("Expected imported game, got error: \(viewModel.importError ?? "nil")")
            return
        }

        XCTAssertEqual(imported.executableName, "HalfLife.exe")
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.executableURL.path))
        XCTAssertEqual(imported.executableSize, 20)

        XCTAssertEqual(gameService.games.count, 1)
        XCTAssertEqual(gameService.games.first?.title, "HalfLife")

        // Auto-created container should be associated with the game.
        let container = containerService.container(for: imported.id)
        XCTAssertNotNil(container)
        XCTAssertEqual(container?.gameID, imported.id)
    }

    func testImportRejectsNonExecutable() async {
        let gameService = GameService(storage: storage)
        let viewModel = ImportViewModel(
            gameService: gameService,
            storageService: storage,
            containerService: ContainerService(storage: storage)
        )

        let source = storageDir.appendingPathComponent("notes.txt")
        try! "hello".data(using: .utf8)!.write(to: source)

        await viewModel.importExecutable(from: source)

        XCTAssertNil(viewModel.importedGame)
        XCTAssertNotNil(viewModel.importError)
        XCTAssertEqual(gameService.games.count, 0)
    }

    func testExecutableDiscoveryFindsImportedFiles() async {
        let gameService = GameService(storage: storage)
        let containerService = ContainerService(storage: storage)
        let viewModel = ImportViewModel(
            gameService: gameService,
            storageService: storage,
            containerService: containerService
        )

        for name in ["A.exe", "B.exe", "C.txt"] {
            let folder = storage.gamesDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? "x".data(using: .utf8)!.write(to: folder.appendingPathComponent(name))
        }

        await viewModel.discoverExecutables()
        let names = viewModel.discoveredExecutables.map(\.lastPathComponent).sorted()
        XCTAssertEqual(names, ["A.exe", "B.exe"])
    }
}