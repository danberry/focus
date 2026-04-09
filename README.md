# Focus

A native iOS app for monitoring the security health, team contributions, and project velocity of your GitHub repositories.

## Features

### Repository Dashboard
- Saved repository list sorted alphabetically, with swipe-to-delete
- Each row shows the repository name and primary language
- Security alert badge displays the total number of open alerts; hidden when zero
- Empty state with a prompt to add your first repository

### Add Repository
- Search by owner and repository name
- Fetches repository metadata (name, primary language) via the GitHub GraphQL API
- Fetches Dependabot, code scanning, and secret scanning alert counts via the GitHub REST API — both requests run in parallel
- Individual alert types that return 403/404 (insufficient permissions) are stored as zero rather than blocking the save
- Saved to local storage via SwiftData

### Security Alerts
Each saved repository tracks three alert types:
- **Dependabot alerts** — dependency vulnerability alerts with package, severity, CVSS score, ecosystem, and manifest path
- **Code scanning alerts** — static analysis findings with rule name and severity level
- **Secret scanning alerts** — detected secrets with type, validity, and public leak flag

Alert totals surface as a badge on each repository row. Alerts can be assigned to codeowners directly from the app, with email draft composition support.

### CODEOWNERS
- Parses the `CODEOWNERS` file from the repository root, `.github/`, or `docs/`
- Stores codeowner entries (handle, path pattern, team flag) in SwiftData
- Implements gitignore-style glob matching (`*` and `**`) for file path resolution

### Pull Requests
- Tracks open pull requests per repository (number, title, author, URL)
- Velocity metrics: merged PR counts for 7-day, 30-day, 90-day, and year-to-date windows with prior-period comparisons

### Teams & Members
- Create custom teams and add GitHub users as members
- Track job disciplines and titles for each member
- Donut chart visualization of team composition by job title
- Discipline-based member reports

### Contribution Tracking
- Syncs GitHub contributions (commits, PRs, reviews, issues) per member over a date range
- Supports organization-scoped contribution queries
- Daily contribution calendar tracking

### Reports
- **Merged PRs today / yesterday / this week** — PRs merged in a given period, grouped by repository
- **Security issues report** — summary of open alerts across all saved repositories
- **Member discipline report** — contribution stats grouped by discipline

### Organizations
- Save GitHub organizations to scope contribution queries
- View organization details and associate with team members

### Authentication & Security
- Sign in with a GitHub Personal Access Token (PAT)
- Token stored securely in the system Keychain with biometric protection (Face ID / Touch ID / passcode)
- Token validated on entry via a GitHub GraphQL API call
- Biometric lock screen on app return from background
- Required token scopes: `repo`, `read:org`, `read:user`

### Background Sync
- Security alerts and CODEOWNERS sync every 8 hours via `BGProcessingTask`
- Contribution data syncs every 24 hours
- Foreground sync triggered automatically if data is stale on app return

## Architecture

```
Models → Networking → Services → Views
```

All networking goes through the `HTTPClient` protocol, making every service fully testable via `MockHTTPClient` without hitting the network.

| Layer | Contents |
|---|---|
| Models | `GitHubUser`, `GitHubRepository`, `GitHubTeam`, `GitHubOrganization`, `SavedRepository`, `SavedOrganization`, `RepositorySecurityMetrics`, `DependabotAlert`, `CodeScanningAlert`, `SecretScanningAlert`, `Codeowner`, `Team`, `Member`, `Discipline`, `JobTitle`, `MemberContribution`, `DailyContribution`, `RepositoryVelocity`, `OpenPullRequest`, `MergedPR`, `GitHubError` |
| Networking | `HTTPClient` (protocol + URLSession impl), `GraphQLClient`, `RESTClient`, `Endpoint` |
| Queries | `UserQueries`, `RepositoryQueries`, `ContributionQueries`, `VelocityQueries`, `ReportQueries` |
| Services | `AuthenticationService`, `UserService`, `RepositoryService`, `SecurityService`, `CodeownersService`, `PullRequestService`, `VelocityService`, `ContributionService`, `BackgroundSyncManager`, `SyncService`, `MergedPRReportService`, `CodeownerEmailService`, `TeamService`, `OrganizationService` |
| Views | `MainTabView`, `LoginView`, `LockView`, `ContentView`, `AddRepositoryView`, `RepositoryDetailView`, security alert views, team/member views, report views, discipline views, organization views, `SettingsView` |
| Persistence | SwiftData (`SavedRepository`, `SavedOrganization`, `DependabotAlert`, `CodeScanningAlert`, `SecretScanningAlert`, `Codeowner`, `Team`, `Member`, `Discipline`, `JobTitle`, `MemberContribution`, `DailyContribution`, `RepositoryVelocity`, `OpenPullRequest`) |
| Utilities | `KeychainHelper`, `CodeownerResolver`, `MailtoComposer` |

**GitHub API usage:**
- GraphQL API v4 — user profiles, repository queries, PR searches, contribution data
- REST API v3 — security alert endpoints, team operations, CODEOWNERS file retrieval, organization details

## Tech Stack

- **Language**: Swift 6
- **UI**: SwiftUI
- **Persistence**: SwiftData
- **Networking**: Custom `HTTPClient` over `URLSession` (no third-party dependencies)
- **Background tasks**: `BackgroundTasks` framework (`BGProcessingTask`)
- **Authentication**: `LocalAuthentication` (Face ID / Touch ID), `Security` (Keychain)
- **Platform**: iOS 26
- **Package management**: Swift Package Manager

## Development

### Requirements

- Xcode 26
- iOS 26 simulator or device
- A GitHub Personal Access Token with `repo`, `read:org`, and `read:user` scopes

### Build & Test

```bash
# Build
xcodebuild -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' build

# Test
xcodebuild -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' test
```

### Project Structure

```
Focus/
├── FocusApp.swift              # @main entry point, auth-conditional root view
├── ContentView.swift           # Repository list with security badges
├── Models/                     # Domain types, SwiftData models, error types
├── Networking/                 # HTTPClient, GraphQLClient, RESTClient, Endpoint
├── Queries/                    # GraphQL query strings
├── Services/                   # Business logic and sync layer
├── Views/                      # SwiftUI views (33 files across 8 feature areas)
├── Extensions/                 # Color extensions
└── Utilities/                  # KeychainHelper, CodeownerResolver, MailtoComposer

FocusTests/
├── Mocks/                      # MockHTTPClient
├── Networking/                 # Client-layer tests
├── Services/                   # Service-layer tests (11 services)
├── Models/                     # Model decoding and computed-property tests
└── Utilities/                  # CodeownerResolver and MailtoComposer tests
```
