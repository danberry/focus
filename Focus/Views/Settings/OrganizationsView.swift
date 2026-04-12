import SwiftUI
import SwiftData

// MARK: - OrganizationsView

struct OrganizationsView: View {
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedOrganization.login) private var organizations: [SavedOrganization]

    @State private var isAddingOrganization = false

    var body: some View {
        Group {
            if organizations.isEmpty {
                ContentUnavailableView(
                    "No Organizations",
                    systemImage: "building.2",
                    description: Text("Tap + to add a GitHub organization.")
                )
            } else {
                List {
                    ForEach(organizations) { org in
                        VStack(alignment: .leading) {
                            Text(org.name ?? org.login)
                                .font(.body)
                            if org.name != nil {
                                Text(org.login)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Organizations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingOrganization = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingOrganization) {
            AddOrganizationView(
                organizationService: OrganizationService(
                    rest: RESTClient(tokenProvider: authService.tokenProvider)
                )
            )
        }
    }

    // MARK: - Private

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(organizations[index])
        }
    }
}

#Preview {
    NavigationStack {
        OrganizationsView()
    }
    .modelContainer(for: SavedOrganization.self, inMemory: true)
}
