import SwiftUI

struct LogsView: View {
    @ObservedObject var logService: LogService
    @State private var filter: LogLevel?

    var body: some View {
        List {
            if filtered.isEmpty {
                Text("No log entries")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filtered) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.level.rawValue)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(levelColor(entry.level))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(levelColor(entry.level).opacity(0.12), in: Capsule())
                            Text(entry.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.timestamp.shortDescription)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(entry.message)
                            .font(.footnote)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("All Levels", action: { filter = nil })
                    Divider()
                    ForEach([LogLevel.debug, .info, .warning, .error], id: \.rawValue) { level in
                        Button(level.rawValue.capitalized) {
                            filter = level
                        }
                    }
                    Divider()
                    Button("Clear", role: .destructive) {
                        logService.clear()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
        }
    }

    private var filtered: [LogEntry] {
        guard let filter else { return logService.entries }
        return logService.entries.filter { $0.level == filter }
    }

    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}