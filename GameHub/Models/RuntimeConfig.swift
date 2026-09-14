import Foundation

struct RuntimeConfig: Codable, Hashable, Sendable {
    var windowsVersion: WindowsVersion
    var dxvkEnabled: Bool
    var dxmtEnabled: Bool
    var mscvrtEnabled: Bool

    static let `default` = RuntimeConfig(
        windowsVersion: .win10,
        dxvkEnabled: true,
        dxmtEnabled: true,
        mscvrtEnabled: true
    )
}

enum WindowsVersion: String, Codable, CaseIterable, Identifiable, Sendable {
    case win7
    case win8
    case win10
    case win11

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .win7: return "Windows 7"
        case .win8: return "Windows 8"
        case .win10: return "Windows 10"
        case .win11: return "Windows 11"
        }
    }
}
