import Foundation

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var shortDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

extension URL {
    var isExecutable: Bool {
        GameHubConstants.defaultExecutableExtensions.contains(pathExtension.lowercased())
    }

    var executableDisplayName: String {
        deletingPathExtension().lastPathComponent
    }
}

extension UUID {
    var shortString: String {
        uuidString.prefix(8).lowercased()
    }
}

extension String {
    var isValidExecutableName: Bool {
        let lowered = lowercased()
        return GameHubConstants.defaultExecutableExtensions.contains { lowered.hasSuffix(".\($0)") }
    }
}

extension Array where Element: Identifiable {
    mutating func moveToTop(_ element: Element) {
        guard let index = firstIndex(where: { $0.id == element.id }) else { return }
        let item = remove(at: index)
        insert(item, at: 0)
    }
}