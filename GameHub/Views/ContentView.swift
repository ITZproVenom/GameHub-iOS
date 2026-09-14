import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            LibraryView()
        }
        .tint(.accentColor)
        .onAppear {
            libraryViewModel.refreshRuntimeStatus()
        }
    }
}