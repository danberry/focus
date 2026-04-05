import SwiftUI

// MARK: - MainTabView

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Repositories", systemImage: "books.vertical") {
                ContentView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: SavedRepository.self, inMemory: true)
}
