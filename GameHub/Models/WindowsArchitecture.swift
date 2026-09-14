import Foundation

enum WindowsArchitecture: String, Codable, CaseIterable, Identifiable, Sendable {
    case x86
    case x86_64
    case arm64

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .x86: return "32-bit (x86)"
        case .x86_64: return "64-bit (x86-64)"
        case .arm64: return "ARM64"
        }
    }

    var shortName: String {
        switch self {
        case .x86: return "x86"
        case .x86_64: return "x86-64"
        case .arm64: return "arm64"
        }
    }

    var defaultValue: String {
        switch self {
        case .x86: return "win32"
        case .x86_64: return "win64"
        case .arm64: return "arm64"
        }
    }
}