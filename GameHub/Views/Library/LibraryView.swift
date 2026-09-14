import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @State private var importViewModel: ImportViewModel?
    @State private var showingImportSheet = false
    @State private var showingSettings = false

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if libraryViewModel.isEmpty {
                    EmptyLibraryView(onImport: { presentImport() })
                } else {
                    libraryContent
                }
            }
            .navigationTitle("GameHub")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    runtimeIndicator
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !libraryViewModel.isEmpty {
                        Menu {
                            sortMenu
                            Divider()
                            Button {
                                libraryViewModel.showFavoritesOnly.toggle()
                            } label: {
                                if libraryViewModel.showFavoritesOnly {
                                    Label("Show Favorites Only", systemImage: "checkmark")
                                } else {
                                    Text("Show Favorites Only")
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }

                        Button {
                            presentImport()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .searchable(
                text: $libraryViewModel.searchText,
                prompt: "Search games"
            )
            .navigationDestination(item: $libraryViewModel.selectedGame) { game in
                GameDetailView(viewModel: makeDetailViewModel(for: game))
            }
            .sheet(isPresented: $showingImportSheet) {
                if let importViewModel {
                    ImportView(viewModel: importViewModel)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: appState.settingsViewModel)
                    .environmentObject(appState)
            }
            .alert("GameHub", isPresented: Binding(
                get: { libraryViewModel.errorMessage != nil },
                set: { if !$0 { libraryViewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(libraryViewModel.errorMessage ?? "")
            }
        }
        .onAppear {
            libraryViewModel.refreshRuntimeStatus()
        }
    }

    private var libraryContent: some View {
        ScrollView {
            header
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(libraryViewModel.filteredGames) { game in
                    GameCardView(
                        game: game,
                        progress: 0,
                        artwork: artwork(for: game),
                        containerStatus: containerStatus(for: game)
                    )
                    .onTapGesture {
                        select(game)
                    }
                    .contextMenu {
                        contextMenu(for: game)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(libraryViewModel.libraryHeaderText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var sortMenu: some View {
        Section("Sort By") {
            ForEach(LibrarySort.allCases) { sort in
                Button {
                    libraryViewModel.sortOrder = sort
                } label: {
                    if libraryViewModel.sortOrder == sort {
                        Label(sort.title, systemImage: "checkmark")
                    } else {
                        Text(sort.title)
                    }
                }
            }
        }
    }

    private var runtimeIndicator: some View {
        Group {
            if let status = libraryViewModel.runtimeStatus {
                switch status.state {
                case .unavailable, .error:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                case .installed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .updateAvailable:
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundStyle(.blue)
                }
            } else {
                Image(systemName: "arrow.clockwise.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.title3)
        .accessibilityLabel("Runtime status")
    }

    private func artwork(for game: Game) -> UIImage? {
        libraryViewModel.artwork(for: game)
    }

    private func containerStatus(for game: Game) -> ContainerStatus? {
        appState.libraryViewModel.container(for: game)?.status
    }

    private func select(_ game: Game) {
        appState.libraryViewModel.selectedGame = game
    }

    private func contextMenu(for game: Game) -> some View {
        Group {
            Button {
                select(game)
            } label: {
                Label("Details", systemImage: "info.circle")
            }
            Button {
                libraryViewModel.play(game: game)
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            Button {
                libraryViewModel.toggleFavorite(game)
            } label: {
                if game.isFavorite {
                    Label("Remove from Favorites", systemImage: "star.slash")
                } else {
                    Label("Add to Favorites", systemImage: "star")
                }
            }
            Divider()
            Button(role: .destructive) {
                libraryViewModel.deleteGame(game)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func presentImport() {
        importViewModel = ImportViewModel(
            gameService: appState.gameService,
            storageService: appState.storageService,
            containerService: appState.containerService
        )
        showingImportSheet = true
    }

    private func makeDetailViewModel(for game: Game) -> GameDetailViewModel {
        GameDetailViewModel(
            game: game,
            gameService: appState.gameService,
            containerService: appState.containerService,
            runtimeService: appState.runtimeService,
            storageService: appState.storageService
        )
    }
}