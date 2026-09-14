import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            List {
                runtimeSection
                generalSection
                logsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                viewModel.loadRuntimeStatus()
            }
        }
    }

    private var runtimeSection: some View {
        Section("Runtime") {
            if viewModel.isLoadingStatus {
                HStack {
                    ProgressView()
                    Text("Checking runtime…")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.runtimeStatuses.isEmpty {
                Text("No runtime providers")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.runtimeStatuses) { status in
                    NavigationLink {
                        RuntimeStatusView(status: status)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(status.providerName)
                                    .font(.headline)
                                Spacer()
                                stateBadge(status.state)
                            }
                            Text(status.capabilities.filter(\.available).count == status.capabilities.count
                                 ? "All capabilities available"
                                 : "\(status.capabilities.filter(\.available).count) of \(status.capabilities.count) capabilities ready")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .headerProminence(.increased)
    }

    private var generalSection: some View {
        Section("General") {
            Picker("Default Windows Architecture", selection: architectureBinding) {
                ForEach(WindowsArchitecture.allCases) { arch in
                    Text(arch.displayName).tag(arch)
                }
            }

            Toggle("Auto-create container on import", isOn: autoContainerBinding)
            Toggle("Cache artwork locally", isOn: cacheArtworkBinding)
        }
    }

    private var logsSection: some View {
        Section {
            NavigationLink {
                LogsView(logService: appState.logService)
            } label: {
                Label("Logs", systemImage: "doc.text")
            }
        }
    }

    private func stateBadge(_ state: RuntimeState) -> some View {
        Group {
            switch state {
            case .unavailable:
                Text("Unavailable")
            case .installed(let version):
                Text(version)
            case .updateAvailable(let current, let latest):
                Text("\(current) → \(latest)")
            case .error(let message):
                Text("Error")
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(badgeColor(state).opacity(0.15), in: Capsule())
        .foregroundStyle(badgeColor(state))
    }

    private func badgeColor(_ state: RuntimeState) -> Color {
        switch state {
        case .installed: return .green
        case .updateAvailable: return .blue
        case .unavailable, .error: return .red
        }
    }

    private var architectureBinding: Binding<WindowsArchitecture> {
        Binding(
            get: { viewModel.settings.defaultWindowsArchitecture },
            set: { newValue in
                viewModel.settings.defaultWindowsArchitecture = newValue
                appState.settings = viewModel.settings
                appState.save()
            }
        )
    }

    private var autoContainerBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.autoCreateContainerOnImport },
            set: { newValue in
                viewModel.settings.autoCreateContainerOnImport = newValue
                appState.settings = viewModel.settings
                appState.save()
            }
        )
    }

    private var cacheArtworkBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.cacheArtworkLocally },
            set: { newValue in
                viewModel.settings.cacheArtworkLocally = newValue
                appState.settings = viewModel.settings
                appState.save()
            }
        )
    }
}

struct RuntimeStatusView: View {
    let status: RuntimeStatus

    var body: some View {
        List {
            Section("Provider") {
                LabeledContent("Name", value: status.providerName)
                LabeledContent("ID", value: status.id)
                LabeledContent("Last checked", value: status.lastChecked.shortDescription)
            }

            Section("State") {
                stateContent
            }

            Section("Capabilities") {
                ForEach(status.capabilities) { report in
                    HStack(alignment: .top) {
                        Image(systemName: report.available ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(report.available ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(report.capability.displayName)
                            if let reason = report.reason, !report.available {
                                Text(reason)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(status.providerName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stateContent: some View {
        Group {
            switch status.state {
            case .unavailable:
                Label("Runtime not installed", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            case .installed(let version):
                Label("Installed — Version \(version)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .updateAvailable(let current, let latest):
                Label("Update available: \(current) → \(latest)", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
            case .error(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Label("Runtime error", systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}