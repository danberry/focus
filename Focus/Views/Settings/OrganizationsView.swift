import SwiftUI
import SwiftData

// MARK: - OrganizationsView

/// Displays the list of saved GitHub organizations.
struct OrganizationsView: View {

    // MARK: - Properties

    /// The authentication service, used to build the `OrganizationService` when adding a new organization.
    @Environment(AuthenticationService.self) private var authService

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var modelContext

    /// The saved organizations, sorted alphabetically by login.
    @Query(sort: \SavedOrganization.login) private var organizations: [SavedOrganization]

    /// Controls whether the add-organization sheet is presented.
    @State private var isAddingOrganization = false

    // MARK: - Body

    /// The view's content.
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
                        NavigationLink(destination: OrganizationDetailView(organization: org)) {
                            HStack(spacing: 12) {
                                OrgAvatarView(organization: org)
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

    // MARK: - Helpers

    /// Deletes organizations at the given offsets from the SwiftData model context.
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
