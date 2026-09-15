import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ImportViewModel

    @State private var showingDocumentPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Image(systemName: "square.and.arrow.down.on.square.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                }

                VStack(spacing: 6) {
                    Text("Import a Windows Executable")
                        .font(.title2.bold())
                    Text("Select a .exe, .msi, .bat or .cmd file from the Files app. It will be copied into GameHub's managed storage.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    viewModel.importError = nil
                    showingDocumentPicker = true
                } label: {
                    Label("Choose File", systemImage: "folder")
                        .font(.headline)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isImporting)

                if viewModel.isImporting {
                    ProgressView("Importing…")
                        .padding(.top, 8)
                }

                if let error = viewModel.importError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isImporting)
                }
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: viewModel.supportedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else {
                        viewModel.importError = "No file was selected."
                        return
                    }
                    Task {
                        await viewModel.importExecutable(from: url)
                    }
                case .failure(let error):
                    viewModel.importError = "Document picker failed: \(error.localizedDescription)"
                }
            }
            .onChange(of: viewModel.importedGame) { _, game in
                if game != nil {
                    dismiss()
                }
            }
        }
    }
}
