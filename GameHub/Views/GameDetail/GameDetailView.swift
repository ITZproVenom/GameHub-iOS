import SwiftUI
import UIKit

struct GameDetailView: View {
    @ObservedObject var viewModel: GameDetailViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroSection
                playSection
                runtimeSection
                containerSection
                settingsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .navigationTitle(viewModel.game.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            artwork
            VStack(spacing: 4) {
                Text(viewModel.game.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(viewModel.game.executableName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var artwork: some View {
        Group {
            if let image = viewModel.artworkImage {
                Image(uiImage: image)
                    .resizable()
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.4), .accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }
        }
        .frame(width: 220, height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }

    // MARK: - Play

    private var playSection: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await viewModel.launch()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLaunching {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text("Launch")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLaunching)

            if viewModel.game.lastPlayed != nil {
                Text("Last played \(viewModel.game.lastPlayed!.relativeDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Runtime

    private var runtimeSection: some View {
        sectionCard(title: "Runtime") {
            HStack {
                Label("Madeira", systemImage: "cpu")
                Spacer()
                Text("Runtime integration pending")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: viewModel.executableExists ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(viewModel.executableExists ? .green : .red)
                Text(viewModel.executableExists ? "Executable present" : "Executable missing")
                    .font(.footnote)
            }
        }
    }

    // MARK: - Container

    private var containerSection: some View {
        sectionCard(title: "Windows Container") {
            if let container = viewModel.container {
                VStack(alignment: .leading, spacing: 12) {
                    containerStatusRow(container)
                    divider
                    infoRow("Prefix", value: container.prefixLocation.path)
                    infoRow("Architecture", value: container.windowsArchitecture.displayName)
                    infoRow("Wine Version", value: container.wineVersion)
                    infoRow("DXVK", value: container.dxvkEnabled ? "Enabled" : "Disabled")
                    infoRow("DXMT", value: container.dxmtEnabled ? "Enabled" : "Disabled")

                    if let lastError = container.lastError {
                        Label(lastError, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 12) {
                        Button {
                            viewModel.resetContainer()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(container.status == .resetting)

                        Button(role: .destructive) {
                            viewModel.deleteContainer()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)

                    let containerVM = makeContainerViewModel(for: container)
                    NavigationLink {
                        containerDetailView(with: containerVM)
                    } label: {
                        Label("Manage Container", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Label("No container for this game yet.", systemImage: "shippingbox")
                        .font(.subheadline)

                    Button {
                        viewModel.createContainer()
                    } label: {
                        Label("Create Container", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onChange(of: viewModel.container) { _, _ in
            // Container state refreshed by the view model.
        }
    }

    private func makeContainerViewModel(for container: Container) -> ContainerViewModel {
        ContainerViewModel(
            container: container,
            containerService: appState.containerService,
            gameService: appState.gameService
        )
    }

    private func containerDetailView(with containerVM: ContainerViewModel) -> some View {
        ContainerDetailView(viewModel: containerVM)
    }

    private func containerStatusRow(_ container: Container) -> some View {
        HStack {
            Label(container.status.title, systemImage: "shippingbox.fill")
                .foregroundStyle(containerStatusColor(container.status))
            Spacer()
            Text(containerStatusHint(container.status))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func containerStatusColor(_ status: ContainerStatus) -> Color {
        switch status {
        case .notCreated: return .gray
        case .creating, .resetting: return .orange
        case .ready, .running: return .green
        case .launching: return .blue
        case .error: return .red
        case .deleted: return .secondary
        }
    }

    private func containerStatusHint(_ status: ContainerStatus) -> String {
        switch status {
        case .notCreated: return "Create a prefix to enable launch."
        case .creating: return "Prefix is being prepared."
        case .ready: return "Prefix is ready."
        case .running: return "Process active."
        case .error: return "See error below."
        case .deleted: return "Prefix removed."
        default: return ""
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        sectionCard(title: "Per-Game Settings") {
            VStack(spacing: 12) {
                infoRow("Windows Version", value: viewModel.game.runtimeConfig.windowsVersion.displayName)
                infoRow("DXVK (D3D11→Vulkan)", value: viewModel.game.runtimeConfig.dxvkEnabled ? "Enabled" : "Disabled")
                infoRow("DXMT (D3D11→Metal)", value: viewModel.game.runtimeConfig.dxmtEnabled ? "Enabled" : "Disabled")
                infoRow("MSVCRT", value: viewModel.game.runtimeConfig.mscvrtEnabled ? "Enabled" : "Disabled")
                if !viewModel.game.launchArguments.isEmpty {
                    infoRow("Launch Arguments", value: viewModel.game.launchArguments.joined(separator: " "))
                }
            }
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Divider().opacity(0.5)
    }

    private func sectionCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .background(Material.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
        }
        .font(.footnote)
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

struct ContainerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ContainerViewModel

    var body: some View {
        List {
            statusSection
            configurationSection
            environmentSection
            dangerSection
        }
        .navigationTitle("Container")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var statusSection: some View {
        Section("Status") {
            HStack {
                Circle()
                    .fill(viewModel.statusColor)
                    .frame(width: 10, height: 10)
                Text(viewModel.statusTitle)
            }
            if let game = viewModel.game {
                LabeledContent("Game", value: game.title)
            }
            LabeledContent("Created", value: viewModel.createdDateDescription)
            LabeledContent("Modified", value: viewModel.modifiedDateDescription)
        }
    }

    private var configurationSection: some View {
        Section("Configuration") {
            Picker("Architecture", selection: architectureBinding) {
                ForEach(WindowsArchitecture.allCases) { arch in
                    Text(arch.displayName).tag(arch)
                }
            }

            LabeledContent("Wine Version", value: viewModel.container.wineVersion)

            Toggle("DXVK", isOn: dxvkBinding)
            Toggle("DXMT", isOn: dxmtBinding)

            LabeledContent("Resolution", value: viewModel.container.resolution.displayString)
            LabeledContent("Graphics Quality", value: viewModel.container.graphicsSettings.textureQuality.rawValue.capitalized)
            LabeledContent("Audio Volume", value: "\(Int(viewModel.container.audioSettings.volume * 100))%")
            LabeledContent("Input Profile", value: inputProfileText)
        }
    }

    private var inputProfileText: String {
        let settings = viewModel.container.inputSettings
        var parts: [String] = []
        if settings.touchControlsEnabled { parts.append("Touch") }
        if settings.gamepadEnabled { parts.append("Gamepad") }
        if settings.keyboardEnabled { parts.append("Keyboard") }
        if settings.mouseEmulationEnabled { parts.append("Mouse") }
        return parts.joined(separator: ", ")
    }

    private var environmentSection: some View {
        Section("Environment") {
            ForEach(Array(viewModel.container.environmentVariables.keys.sorted()), id: \.self) { key in
                Text("\(key) = \(viewModel.container.environmentVariables[key] ?? "")")
                    .font(.footnote.monospaced())
            }
            if viewModel.container.environmentVariables.isEmpty {
                Text("No custom environment variables")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dangerSection: some View {
        Section("Danger Zone") {
            Button(role: .destructive) {
                viewModel.resetContainer()
            } label: {
                Label("Reset Container", systemImage: "arrow.counterclockwise")
            }
            .disabled(viewModel.isResetting)

            Button(role: .destructive) {
                viewModel.deleteContainer()
                dismiss()
            } label: {
                Label("Delete Container", systemImage: "trash")
            }
            .disabled(viewModel.isDeleting)
        }
    }

    private var architectureBinding: Binding<WindowsArchitecture> {
        Binding(
            get: { viewModel.container.windowsArchitecture },
            set: { viewModel.updateArchitecture($0) }
        )
    }

    private var dxvkBinding: Binding<Bool> {
        Binding(
            get: { viewModel.container.dxvkEnabled },
            set: { viewModel.toggleDXVK(enabled: $0) }
        )
    }

    private var dxmtBinding: Binding<Bool> {
        Binding(
            get: { viewModel.container.dxmtEnabled },
            set: { viewModel.toggleDXMT(enabled: $0) }
        )
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}