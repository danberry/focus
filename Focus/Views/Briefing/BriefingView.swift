import SwiftUI
import SwiftData

// MARK: - BriefingView

/// The top-level Focus Briefing screen — an editorial weekly engineering dashboard.
///
/// `BriefingView` orchestrates the full briefing layout: the serif hero verdict,
/// KPI strip, and three opinionated sections (Shipped, Blocked, Security). On
/// first appear it asks ``BriefingManager`` to generate a ``Briefing`` for the
/// previous calendar week; on subsequent visits the cached result renders
/// instantly without any network activity.
struct BriefingView: View {

    // MARK: - Properties

    /// The SwiftData model context, injected from the root `ModelContainer`.
    @Environment(\.modelContext) private var context

    /// The authentication service used to construct the GraphQL client for PR fetches.
    @Environment(AuthenticationService.self) private var authService

    /// The briefing cache — holds generated briefings for each (week, scope) pair.
    @Environment(BriefingManager.self) private var briefingManager

    /// All teams in the store, sorted by name for the scope picker.
    @Query(sort: \Team.name) private var teams: [Team]

    /// All departments in the store, sorted by name for the scope picker.
    @Query(sort: \Department.name) private var departments: [Department]

    /// All saved organizations in the store, sorted by login for the scope picker.
    @Query(sort: \SavedOrganization.login) private var organizations: [SavedOrganization]

    /// Closure invoked when an attention card's action button is tapped.
    ///
    /// Defaults to a no-op — on iPad, `iPadContentView` injects a push action.
    var onAttentionAction: (BriefingAttentionItem) -> Void = { _ in }

    /// The currently selected scope used to filter the briefing.
    @State private var scope: BriefingScope = .all

    // MARK: - Derived state

    private var briefing: Briefing? { briefingManager.briefing(for: scope) }
    private var isLoading: Bool { briefingManager.isLoading(for: scope) }

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
                if isLoading {
                    ProgressView()
                        .tint(BriefingColor.ink)
                } else {
                    Button {
                        Task {
                            let service = makeService()
                            await briefingManager.refresh(scope: scope, service: service, context: context)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(BriefingColor.ink)
                    }
                }
            }
            ToolbarItem(placement: .topBarLeading) {
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
            let service = makeService()
            await briefingManager.load(scope: scope, service: service, context: context)
        }
        .onChange(of: scope.displayName) {
            Task {
                let service = makeService()
                await briefingManager.load(scope: scope, service: service, context: context)
            }
        }
    }

    // MARK: - Helpers

    /// The shared rule-and-spacing divider rendered between sections.
    private var sectionDivider: some View {
        Divider()
            .foregroundStyle(BriefingColor.rule2)
    }

    private func makeService() -> BriefingService {
        BriefingService(
            graphQL: GraphQLClient(tokenProvider: authService.tokenProvider),
            rest: RESTClient(tokenProvider: authService.tokenProvider)
        )
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
    .environment(BriefingManager())
}
