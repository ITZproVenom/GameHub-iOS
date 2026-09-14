import XCTest
@testable import GameHub

final class RuntimeTests: XCTestCase {

    func testMadeiraProviderMetadata() {
        let provider = MadeiraRuntimeProvider()
        XCTAssertEqual(provider.id, "madeira")
        XCTAssertEqual(provider.name, "Madeira")
        XCTAssertEqual(provider.pinnedCommit, GameHubConstants.madeiraPinnedCommit)
        XCTAssertEqual(provider.projectURL, GameHubConstants.madeiraProjectURL)
    }

    func testMadeiraStateUnavailableWithoutBinaries() async {
        let provider = MadeiraRuntimeProvider()
        let state = await provider.currentState()
        guard case .unavailable = state else {
            XCTFail("Expected unavailable state, got something else")
            return
        }
    }

    func testSupportedCapabilitiesIncludeFullPipeline() async {
        let provider = MadeiraRuntimeProvider()
        let caps = await provider.supportedCapabilities()
        XCTAssertTrue(caps.contains(.wineExecution))
        XCTAssertTrue(caps.contains(.x86Translation))
        XCTAssertTrue(caps.contains(.d3d11ToMetal))
        XCTAssertTrue(caps.contains(.jitCompilation))
        XCTAssertTrue(caps.contains(.dynamicLibraryLoading))
    }

    func testCapabilityUnavailableWhenRuntimeMissing() async {
        let provider = MadeiraRuntimeProvider()
        let available = await provider.isCapabilityAvailable(.wineExecution)
        XCTAssertFalse(available)
    }

    func testLaunchWithoutBinariesReturnsRuntimeNotInstalled() async {
        let provider = MadeiraRuntimeProvider()
        let game = Game(
            title: "Test",
            executableName: "test.exe",
            executableURL: URL(fileURLWithPath: "/tmp/test.exe")
        )
        let result = await provider.launch(
            executableURL: game.executableURL,
            prefixURL: URL(fileURLWithPath: "/tmp/prefix"),
            arguments: game.launchArguments,
            environment: [:],
            config: game.runtimeConfig
        )
        guard case .runtimeNotInstalled = result else {
            XCTFail("Expected runtimeNotInstalled, got \(result)")
            return
        }
    }

    func testRuntimeStatusReportsHonestUnavailable() async {
        let provider = MadeiraRuntimeProvider()
        let status = await provider.runtimeStatus()
        XCTAssertEqual(status.id, "madeira")
        XCTAssertEqual(status.providerName, "Madeira")

        switch status.state {
        case .unavailable:
            // Expected without bundled binaries.
            break
        case .error(let message):
            XCTAssertFalse(message.isEmpty)
        default:
            XCTFail("Runtime should not report installed without binaries")
        }

        // None of the capabilities should report available when runtime is missing.
        let available = status.capabilities.filter(\.available)
        XCTAssertEqual(available.count, 0)
    }
}