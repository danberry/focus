# Focus

A native iOS app for monitoring the security health of your GitHub repositories.

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

### Security Metrics
Each saved repository tracks three alert types:
- **Dependabot alerts** — dependency vulnerability alerts
- **Code scanning alerts** — static analysis findings
- **Secret scanning alerts** — detected secrets in code

The total is surfaced as a badge on each list row.

### Authentication
- Sign in with a GitHub Personal Access Token (PAT)
- Token stored securely in the system Keychain
- Token validated on entry via a GitHub GraphQL API call
- Required token scopes: `repo`, `read:org`, `read:user`

## Architecture

```
Models → Networking → Services → Views
```

All networking goes through the `HTTPClient` protocol, making every service fully testable via `MockHTTPClient` without hitting the network.

| Layer | Contents |
|---|---|
| Models | `GitHubUser`, `GitHubRepository`, `GitHubTeam`, `SavedRepository`, `RepositorySecurityMetrics` |
| Networking | `HTTPClient` (protocol + URLSession impl), `GraphQLClient`, `RESTClient` |
| Services | `AuthenticationService`, `UserService`, `RepositoryService`, `TeamService`, `SecurityService` |
| Views | `LoginView`, `ContentView`, `AddRepositoryView` |
| Persistence | SwiftData (`SavedRepository`) |

**GitHub API usage:**
- GraphQL API v4 — user and repository queries
- REST API v3 — security alert endpoints and team operations

## Tech Stack

- **Language**: Swift 6
- **UI**: SwiftUI
- **Persistence**: SwiftData
- **Networking**: Custom `HTTPClient` over `URLSession` (no third-party dependencies)
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
├── Models/                     # Domain types and SwiftData model
├── Networking/                 # HTTPClient, GraphQLClient, RESTClient
├── Queries/                    # GraphQL query strings
├── Services/                   # Business logic layer
├── Views/                      # SwiftUI views
└── Utilities/                  # KeychainHelper

FocusTests/
├── Mocks/                      # MockHTTPClient
├── Networking/                 # Client-layer tests
├── Services/                   # Service-layer tests
└── Models/                     # Model decoding and computed-property tests
```
