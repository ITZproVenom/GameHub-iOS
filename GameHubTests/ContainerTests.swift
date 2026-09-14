import XCTest
@testable import GameHub

final class ContainerTests: XCTestCase {

    private var storageDir: URL!
    private var storage: StorageService!
    private var containerService: ContainerService!

    private var uniqueBase: URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GameHubContainerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeGame() -> Game {
        Game(
            title: "Wine Test",
            executableName: "test.exe",
            executableURL: URL(fileURLWithPath: "/tmp/test.exe")
        )
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        storageDir = uniqueBase
        storage = StorageService(baseDirectory: storageDir)
        try? storage.ensureBaseStructure()
        containerService = ContainerService(storage: storage)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storageDir)
        try super.tearDownWithError()
    }

    func testCreateContainerAssociatedWithGame() async throws {
        let game = makeGame()
        let container = try await containerService.createContainer(for: game, architecture: .x86_64)

        XCTAssertEqual(container.gameID, game.id)
        XCTAssertEqual(container.windowsArchitecture, .x86_64)
        XCTAssertEqual(container.status, .ready)
        XCTAssertTrue(FileManager.default.fileExists(atPath: container.prefixLocation.path))
    }

    func testDuplicateContainerThrowsAlreadyExists() async {
        let game = makeGame()
        _ = try? await containerService.createContainer(for: game, architecture: .x86_64)

        do {
            _ = try await containerService.createContainer(for: game, architecture: .x86_64)
            XCTFail("Expected alreadyExists error")
        } catch ContainerError.alreadyExists {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCheckStateOnMissingPrefixReturnsNotCreated() async {
        let game = makeGame()
        let container = try! await containerService.createContainer(for: game, architecture: .x86_64)

        try? FileManager.default.removeItem(at: container.prefixLocation)

        let status = await containerService.checkContainerState(withID: container.id)
        XCTAssertEqual(status, .notCreated)
    }

    func testCheckStateOnConfiguredPrefixReturnsReady() async throws {
        let game = makeGame()
        let container = try! await containerService.createContainer(for: game, architecture: .x86_64)

        try "reg".data(using: .utf8)!.write(
            to: container.prefixLocation.appendingPathComponent("user.reg")
        )

        let status = await containerService.checkContainerState(withID: container.id)
        XCTAssertEqual(status, .ready)
    }

    func testResetContainerClearsPrefix() async throws {
        let game = makeGame()
        let container = try! await containerService.createContainer(for: game, architecture: .x86_64)

        try "sample".data(using: .utf8)!.write(
            to: container.prefixLocation.appendingPathComponent("drive_c")
        )

        try await containerService.resetContainer(withID: container.id)

        let driveC = container.prefixLocation.appendingPathComponent("drive_c")
        XCTAssertFalse(FileManager.default.fileExists(atPath: driveC.path))
        XCTAssertEqual(containerService.loadContainer(withID: container.id)?.status, .ready)
    }

    func testDeleteContainerRemovesPrefixAndEntry() async throws {
        let game = makeGame()
        let container = try! await containerService.createContainer(for: game, architecture: .x86_64)

        try await containerService.deleteContainer(withID: container.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: container.prefixLocation.path))
        XCTAssertNil(containerService.loadContainer(withID: container.id))
    }

    func testContainerPersistenceRoundTrip() async throws {
        let game = makeGame()
        _ = try await containerService.createContainer(for: game, architecture: .x86_64)
        containerService.save()

        let reloaded = ContainerService(storage: storage)
        reloaded.loadContainers()
        XCTAssertEqual(reloaded.containers.count, 1)
        XCTAssertEqual(reloaded.containers.first?.gameID, game.id)
    }

    func testUpdateContainerPersistsChanges() async throws {
        let game = makeGame()
        var container = try await containerService.createContainer(for: game, architecture: .x86_64)

        container.dxvkEnabled = false
        container.dxmtEnabled = false
        container.environmentVariables["FOO"] = "bar"
        containerService.updateContainer(container)

        let reloaded = containerService.loadContainer(withID: container.id)
        XCTAssertEqual(reloaded?.dxvkEnabled, false)
        XCTAssertEqual(reloaded?.dxmtEnabled, false)
        XCTAssertEqual(reloaded?.environmentVariables["FOO"], "bar")
    }
}