import SwiftUI

// MARK: - MainTabView

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Repositories", systemImage: "books.vertical") {
                ContentView()
            }
            Tab("Teams", systemImage: "person.2") {
                TeamsView()
            }
            Tab("Job Titles", systemImage: "briefcase") {
                JobTitlesView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [SavedRepository.self, Team.self, Member.self, MemberContribution.self, JobTitle.self], inMemory: true)
}
