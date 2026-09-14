import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "square.grid.2x2.fill")
                }

            CloudPlayView()
                .tabItem {
                    Label("Cloud", systemImage: "cloud.fill")
                }

            ImportView()
                .tabItem {
                    Label("Import", systemImage: "plus.circle.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(Color(red: 0.49, green: 0.23, blue: 0.93))
    }
}

#Preview {
    ContentView()
}
