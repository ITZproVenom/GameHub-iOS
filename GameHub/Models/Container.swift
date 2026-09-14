import Foundation

enum ContainerStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case notCreated
    case creating
    case ready
    case launching
    case running
    case error
    case resetting
    case deleted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notCreated: return "Not Created"
        case .creating: return "Creating"
        case .ready: return "Ready"
        case .launching: return "Launching"
        case .running: return "Running"
        case .error: return "Error"
        case .resetting: return "Resetting"
        case .deleted: return "Deleted"
        }
    }
}

struct Container: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var gameID: UUID
    var prefixLocation: URL
    var windowsArchitecture: WindowsArchitecture
    var wineVersion: String
    var environmentVariables: [String: String]
    var resolution: Resolution
    var graphicsSettings: GraphicsSettings
    var audioSettings: AudioSettings
    var inputSettings: InputSettings
    var dxvkEnabled: Bool
    var dxmtEnabled: Bool
    var createdDate: Date
    var modifiedDate: Date
    var status: ContainerStatus
    var lastError: String?

    init(
        id: UUID = UUID(),
        gameID: UUID,
        prefixLocation: URL,
        windowsArchitecture: WindowsArchitecture = .x86_64,
        wineVersion: String = "madeira-0.1",
        environmentVariables: [String: String] = [:],
        resolution: Resolution = Resolution.default,
        graphicsSettings: GraphicsSettings = GraphicsSettings.default,
        audioSettings: AudioSettings = AudioSettings.default,
        inputSettings: InputSettings = InputSettings.default,
        dxvkEnabled: Bool = true,
        dxmtEnabled: Bool = true,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        status: ContainerStatus = .notCreated,
        lastError: String? = nil
    ) {
        self.id = id
        self.gameID = gameID
        self.prefixLocation = prefixLocation
        self.windowsArchitecture = windowsArchitecture
        self.wineVersion = wineVersion
        self.environmentVariables = environmentVariables
        self.resolution = resolution
        self.graphicsSettings = graphicsSettings
        self.audioSettings = audioSettings
        self.inputSettings = inputSettings
        self.dxvkEnabled = dxvkEnabled
        self.dxmtEnabled = dxmtEnabled
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.status = status
        self.lastError = lastError
    }

    func with(modifiedAt date: Date = Date()) -> Container {
        var copy = self
        copy.modifiedDate = date
        return copy
    }
}

struct Resolution: Codable, Hashable, Sendable {
    var width: Int
    var height: Int
    var refreshRate: Int

    static let `default` = Resolution(width: 1920, height: 1080, refreshRate: 60)

    var displayString: String {
        "\(width) × \(height) @ \(refreshRate)Hz"
    }
}

struct GraphicsSettings: Codable, Hashable, Sendable {
    var vsyncEnabled: Bool
    var maxFPS: Int?
    var renderingScale: Double
    var textureQuality: QualityLevel

    static let `default` = GraphicsSettings(
        vsyncEnabled: true,
        maxFPS: nil,
        renderingScale: 1.0,
        textureQuality: .medium
    )
}

struct AudioSettings: Codable, Hashable, Sendable {
    var volume: Double
    var audioEngineEnabled: Bool
    var outputDevice: String?

    static let `default` = AudioSettings(
        volume: 1.0,
        audioEngineEnabled: true,
        outputDevice: nil
    )
}

struct InputSettings: Codable, Hashable, Sendable {
    var touchControlsEnabled: Bool
    var gamepadEnabled: Bool
    var keyboardEnabled: Bool
    var mouseEmulationEnabled: Bool
    var mouseSensitivity: Double

    static let `default` = InputSettings(
        touchControlsEnabled: true,
        gamepadEnabled: true,
        keyboardEnabled: false,
        mouseEmulationEnabled: true,
        mouseSensitivity: 1.0
    )
}

enum QualityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high
    case ultra

    var id: String { rawValue }
}