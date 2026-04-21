import SwiftUI
import SwiftData

// MARK: - BriefingView

/// The top-level Focus Briefing screen — an editorial weekly engineering dashboard.
///
/// `BriefingView` orchestrates the full briefing layout: the serif hero verdict,
/// KPI strip, and three opinionated sections (Shipped, Blocked, Security). On
/// appear it constructs a ``BriefingService`` from the ambient
/// ``AuthenticationService`` and asks it to assemble a ``Briefing`` for the
/// previous calendar week, rendering a loading indicator until the result lands.
struct BriefingView: View {

    // MARK: - Properties

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var context

    /// The authentication service used to construct the GraphQL client for PR fetches.
    @Environment(AuthenticationService.self) private var authService

    /// All teams in the store, sorted by name for the scope picker.
    @Query(sort: \Team.name) private var teams: [Team]

    /// All departments in the store, sorted by name for the scope picker.
    @Query(sort: \Department.name) private var departments: [Department]

    /// All saved organizations in the store, sorted by login for the scope picker.
    @Query(sort: \SavedOrganization.login) private var organizations: [SavedOrganization]

    /// The assembled briefing payload, or `nil` while loading.
    @State private var briefing: Briefing?

    /// Whether the briefing generation task is currently in flight.
    @State private var isLoading = false

    /// Closure invoked when an attention card's action button is tapped.
    ///
    /// Defaults to a no-op — on iPad, `iPadContentView` injects a push action.
    var onAttentionAction: (BriefingAttentionItem) -> Void = { _ in }

    /// The currently selected scope used to filter the briefing.
    @State private var scope: BriefingScope = .all

    // MARK: - Body

    /// The view's content.
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if let briefing {

                    // MARK: Hero
                    BriefingHeroSection(
                        hero: briefing.hero,
                        attention: briefing.attention,
                        weekRange: briefing.weekRange,
                        volume: briefing.volume,
                        onAttentionAction: onAttentionAction
                    )
                    .padding(.horizontal, 36)
                    .padding(.bottom, 56)

                    // MARK: KPIs
                    BriefingKPISection(kpis: briefing.kpis)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 33)
                        .background(.gray100)

                    // MARK: Shipped
                    BriefingShippedSection(
                        shipped: briefing.shipped,
                        onSeeAll: nil
                    )
                    .padding(.horizontal, 36)
                    .padding(.top, 56)
                    .padding(.bottom, 33)

                    sectionDivider

                    // MARK: Blocked
                    BriefingBlockedSection(
                        blocked: briefing.blocked,
                        onDM: nil,
                        onOpen: nil
                    )
                    .padding(.horizontal, 36)
                    .padding(.top, 56)
                    .padding(.bottom, 33)

                    sectionDivider

                    // MARK: Security
                    BriefingSecuritySection(
                        security: briefing.security,
                        onTriage: nil
                    )
                    .padding(.horizontal, 36)
                    .padding(.top, 56)
                    .padding(.bottom, 33)

                } else {

                    // MARK: Loading state
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 60)
                }
            }
        }
        .contentMargins(.top, 64)
        .background(BriefingColor.paper)
        .navigationTitle("Briefing")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("All") { scope = .all }
                    if !teams.isEmpty {
                        Section("Teams") {
                            ForEach(teams) { team in
                                Button(team.name) { scope = .team(team) }
                            }
                        }
                    }
                    if !departments.isEmpty {
                        Section("Departments") {
                            ForEach(departments) { dept in
                                Button(dept.name) { scope = .department(dept) }
                            }
                        }
                    }
                    if !organizations.isEmpty {
                        Section("Organizations") {
                            ForEach(organizations) { org in
                                Button(org.name ?? org.login) { scope = .organization(org) }
                            }
                        }
                    }
                } label: {
                    Label(scope.displayName, systemImage: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(BriefingColor.ink)
                }
            }
        }
        .task {
            isLoading = true
            let client = GraphQLClient(tokenProvider: authService.tokenProvider)
            let service = BriefingService(graphQL: client)
            briefing = await service.generate(scope: scope, in: context)
            isLoading = false
        }
        .onChange(of: scope.displayName) {
            Task {
                isLoading = true
                let client = GraphQLClient(tokenProvider: authService.tokenProvider)
                let service = BriefingService(graphQL: client)
                briefing = await service.generate(scope: scope, in: context)
                isLoading = false
            }
        }
    }

    // MARK: - Helpers

    /// The shared rule-and-spacing divider rendered between sections.
    private var sectionDivider: some View {
        Divider()
            .foregroundStyle(BriefingColor.rule2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BriefingView()
    }
    .modelContainer(
        for: [
            SavedRepository.self,
            Team.self,
            Department.self,
            SavedOrganization.self,
            Member.self,
            MemberContribution.self,
            Discipline.self,
            JobTitle.self,
            DailyContribution.self,
            DependabotAlert.self,
            RepositoryVelocity.self,
            OpenPullRequest.self
        ],
        inMemory: true
    )
    .environment(AuthenticationService())
}
