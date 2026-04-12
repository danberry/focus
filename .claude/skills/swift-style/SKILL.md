---
name: swift-style
description: |
  Focus iOS app code organization and documentation standard. Apply this skill whenever creating, editing, or reorganizing Swift files in the Focus project. This includes: adding DocC documentation to types, properties, and methods; organizing file contents with MARK sections; adding TODOs for known limitations; restructuring files to follow the layer-specific conventions (services, models, views, protocols, tests); and moving or creating view files into the correct tab-based subdirectory. Also use this skill when the user explicitly asks to "document", "organize", "clean up", or "apply the style guide" to existing files — even if they don't name the skill directly. If you're touching a Swift file in Focus for any reason, consult this skill to ensure the result conforms.
---

# Focus Swift Style Guide

A unified standard for code organization and DocC documentation across all Swift files in the Focus iOS project. Applies to the app target (`Focus/`) and test target (`FocusTests/`).

---

## Part 1: Universal Rules

These apply to every file regardless of layer.

**Rule 1 — DocC on every named symbol.**
Every type, stored property, computed property, method, initializer, and enum case gets a `///` doc comment. Access control is irrelevant: `private` methods and `private` types are documented the same as internal or public ones. No exceptions.

**Rule 2 — MARK dash form at type level; no-dash inside bodies.**
Type-level sections use `// MARK: - SectionName` (with dash). Inline sectioning *inside* method bodies — for example, dividing a SwiftUI `body` into named regions — uses `// MARK: SectionName` (no dash). The dash form drives Xcode's minimap and jump bar; the no-dash form is a lightweight inline separator.

**Rule 3 — Section order is consistent across all types.**
The top-level structure within any type follows:
1. Properties
2. Init
3. Type-specific middle sections (varies by layer — see below)
4. Private

**Rule 4 — Private types at the bottom, labeled.**
Any private type defined at file scope (not nested inside another type) lives below the main type declaration, under its own `// MARK: -` header.

**Rule 5 — TODOs mark concrete, named limitations.**
`// TODO:` is for real technical debt with an identifiable failure mode, not aspirational features. Format: `// TODO: [what to do] — [why it matters / what breaks without it]`. If you can't fill in both halves, it doesn't belong as a TODO.

**Rule 6 — DocC summary lines.**
One sentence per symbol. Active voice. For methods, use imperative mood ("Fetches…", "Builds…", "Returns…"). For properties and types, use descriptive phrasing ("The URL session used for…", "A lightweight count-only…"). Apply period-or-no-period consistently within a file.

**Rule 7 — Parameters/Returns/Throws only when non-obvious.**
`- Parameter owner:` adds nothing when the name and type are already clear. Include parameter docs when there's a constraint, a valid range, a side-effect, or a non-obvious meaning. Always document `- Returns:` when the return value has behavior that isn't derivable from the type alone (e.g., "Returns `nil` if the feature is not enabled"). Always document `- Throws:` when the method throws, noting *when* it throws vs. when it silently fails.

---

## Part 2: Services

**MARK structure:**
```swift
// MARK: - ServiceName

struct ServiceName: Sendable {

    // MARK: - Properties

    // MARK: - Init

    // MARK: - [Primary Responsibility A]   // e.g., Metrics, Sync, Fetch

    // MARK: - [Primary Responsibility B]   // e.g., Assignees, Write

    // MARK: - Private
}

// MARK: - API Response Types

private struct SomeResponse: Decodable, Sendable { ... }
```

Group by responsibility, not by technical classification. Methods that share a contract (e.g., all full-replace SwiftData syncs) belong together. A reader scanning section names should be able to infer the service's capability surface without reading method bodies.

**DocC — type level.**
Describe the service's role and, if it has distinct operational modes, call them out explicitly:
```swift
/// Fetches and persists security alert data for GitHub repositories.
///
/// `SecurityService` operates in two modes:
/// - **Metrics**: count-only fetches for badge display (`fetchMetrics(owner:repo:)`)
/// - **Sync**: full alert fetches that write rich objects to SwiftData
///
/// All network calls go through the injected ``RESTClient``.
```

**DocC — methods.**
Capture what isn't visible from the signature — error behavior (throws vs. silently discards), SwiftData side effects, concurrent execution patterns:
```swift
/// Fetches open alert counts for all three security alert types in parallel.
///
/// Count-only — does not persist alert detail to SwiftData.
/// A 403 or 404 for any alert type is treated as `nil` and stored as `0`.
///
/// - Parameters:
///   - owner: The repository owner login (user or organization).
///   - repo: The repository name.
/// - Returns: A ``RepositorySecurityMetrics`` with counts for all three alert types.
```

**DocC — private helpers.**
One-line summary of what they encapsulate:
```swift
/// Fetches alerts from `path`, returning `nil` on any error.
private func fetch(path: String, queryItems: [URLQueryItem]) async -> [AlertStub]? { ... }
```

**DocC — private response types.**
One-line summary per struct and per level of nesting:
```swift
/// A GitHub REST API response for a single Dependabot alert.
private struct DependabotAlertResponse: Decodable, Sendable {

    /// The GitHub Security Advisory associated with this alert.
    struct SecurityAdvisory: Decodable, Sendable {

        /// The CVSS score for this advisory, if available.
        struct CVSS: Decodable, Sendable { ... }
    }
}
```

Intentionally empty stubs warrant an explanation:
```swift
/// An intentionally empty decodable type used for counting alert responses.
///
/// Decoding only the array length avoids deserializing the full alert body
/// across potentially hundreds of records.
private struct AlertStub: Decodable, Sendable {}
```

---

## Part 3: Models (`@Model` classes)

**MARK structure:**
```swift
// MARK: - ModelName

@Model
final class ModelName {

    // MARK: - Properties

    // MARK: - Init

    // MARK: - Relationships

    // MARK: - Computed
}
```

Stored scalar properties and `@Relationship` properties are separated because they have meaningfully different semantics. Grouping them together makes it immediately clear which properties are SwiftData graph edges.

**DocC — type level.**
Describe what the model persists and its role in the SwiftData graph:
```swift
/// A GitHub repository that has been saved to the user's watch list.
///
/// `SavedRepository` is the root entity in the SwiftData graph. All alert
/// types, velocity metrics, pull requests, and code owners cascade-delete
/// when the repository is removed.
```

**DocC — stored properties.**
Note non-obvious constraints. Optional properties should say why they're optional:
```swift
/// The repository's primary programming language, or `nil` if GitHub reports none.
var primaryLanguage: String?
```

**DocC — `@Relationship` properties.**
Always document the delete rule and the inverse — even though the attribute encodes it, Xcode Quick Help shows the doc comment:
```swift
/// Open Dependabot alerts for this repository.
///
/// Cascade-deleted when the repository is removed. Inverse of ``DependabotAlert/repository``.
@Relationship(deleteRule: .cascade, inverse: \DependabotAlert.repository)
var dependabotAlertDetails: [DependabotAlert] = []
```

**DocC — init.**
Document parameters with non-obvious defaults:
```swift
/// Creates a new saved repository.
///
/// - Parameters:
///   - githubId: The stable GitHub node ID for the repository.
///   - displayName: The user-facing label shown in lists and navigation titles.
///   - dependabotAlerts: Initial open alert count; defaults to `0` until synced.
```

**DocC — computed properties.**
Describe what they aggregate and when to prefer them:
```swift
/// The sum of all three security alert type counts.
///
/// Use for badge display. Prefer individual alert count properties when the
/// breakdown by type matters.
var totalSecurityAlerts: Int { ... }
```

---

## Part 4: Views (SwiftUI)

**MARK structure:**
```swift
// MARK: - ViewName

struct ViewName: View {

    // MARK: - Properties

    // MARK: - Body

    var body: some View { ... }

    // MARK: - Helpers
}

// MARK: - PrivateNestedViewName

private struct PrivateNestedViewName: View {
    // same structure
}
```

Properties section lists all stored data in this order: `let` inputs, `@Environment`, `@Query`, `@State`. This mirrors dependency direction — required external data first, local state last.

Inside `body`, use no-dash inline marks for significant list sections or major branches:
```swift
var body: some View {
    List {
        // MARK: Velocity
        Section { ... }

        // MARK: Open Pull Requests
        Section { ... }
    }
}
```

Private nested views always live at file scope, below the main type, under their own `// MARK: -` header. They are never nested inside the parent type's declaration.

**DocC — type level.**
One sentence describing what the view displays:
```swift
/// Displays security metrics, velocity, pull requests, and code owners for a repository.
```

**DocC — `body`.**
Brief — it's a protocol requirement with a well-known role:
```swift
/// The view's content.
var body: some View { ... }
```

**DocC — `let` inputs.**
Document what the view needs:
```swift
/// The repository whose detail data this view displays.
let repository: SavedRepository
```

**DocC — `@State` properties.**
Document what UI state they track and what drives changes:
```swift
/// The currently selected velocity period, controlling which metric is shown in the hero row.
@State private var selectedPeriod: VelocityPeriod = .yearToDate
```

**DocC — `@Environment` properties.**
Document what they provide and where they originate:
```swift
/// The SwiftData model context, injected from the root `ModelContainer`.
@Environment(\.modelContext) private var context
```

**DocC — private helper methods.**
One-line summary of what they compute:
```swift
/// Returns a human-readable label for how long a pull request has been open.
private func daysOpenLabel(_ createdAt: Date) -> String { ... }
```

**DocC — private nested views.**
Doc comment on the type; `body` gets `/// The view's content.` same as the parent:
```swift
/// A hero-style row displaying merged PR count and year-over-year trend for a velocity period.
private struct VelocityHeroRow: View {

    /// The velocity comparison data to render.
    let comparison: VelocityComparison

    /// The view's content.
    var body: some View { ... }

    /// Returns the SF Symbol name for the given trend direction.
    private func trendIcon(_ trend: VelocityComparison.Trend) -> String { ... }
}
```

---

## Part 5: Protocols + Concrete Conformances

**MARK structure:**
```swift
// MARK: - ProtocolName

protocol ProtocolName { ... }

// MARK: - ConcreteName

struct ConcreteName: ProtocolName {

    // MARK: - Properties

    // MARK: - Init

    // MARK: - [Domain groupings, e.g., GET / PATCH / Private]

    // MARK: - Private
}
```

When a protocol and its primary conformance live in the same file (e.g., `HTTPClient.swift`), separate them with top-level MARK headers. No nesting of one inside the other.

**DocC — protocol type.**
Document the contract — what conforming types must do, not how:
```swift
/// Executes HTTP requests and returns raw response data.
///
/// Conforming types are responsible for transport only. Error mapping,
/// decoding, and auth headers are the caller's responsibility.
protocol HTTPClient: Sendable { ... }
```

**DocC — protocol requirements.**
These are the most critical doc comments in the file — they define the contract every conformer must satisfy:
```swift
/// Executes a URL request and returns the raw response data and HTTP metadata.
///
/// - Parameter request: The fully constructed request to execute.
/// - Returns: The raw response body and HTTP response metadata.
/// - Throws: Any transport-layer error encountered during execution.
func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
```

**DocC — concrete type.**
Describe the implementation, not the contract:
```swift
/// An `HTTPClient` implementation backed by `URLSession`.
struct URLSessionHTTPClient: HTTPClient { ... }
```

**DocC — private helpers on concrete types.**
Document what they encapsulate and any non-obvious behavior:
```swift
/// Maps non-2xx HTTP status codes to typed ``GitHubError`` values.
///
/// - 401 → ``GitHubError/unauthorized``
/// - 403 with exhausted rate limit → ``GitHubError/rateLimited(resetDate:)``
/// - 403 otherwise → ``GitHubError/forbidden``
/// - 404 → ``GitHubError/notFound``
private func mapHTTPErrors(_ response: HTTPURLResponse) throws { ... }
```

**DocC — private stored properties with complex initialization.**
Document the configuration they apply:
```swift
/// A JSON decoder configured for GitHub API responses.
///
/// Applies snake_case key conversion and ISO 8601 date decoding.
private let decoder: JSONDecoder = { ... }()
```

---

## Part 6: Tests

**MARK structure:**
```swift
@Suite("TypeName Tests")
@MainActor  // if applicable — add inline comment explaining why
struct TypeNameTests {

    // Setup properties (no MARK needed for 1–2 properties)
    let mockHTTP = MockHTTPClient()

    // MARK: - Setup   (only if there are multiple factory methods)

    // MARK: - methodUnderTest

    // MARK: - anotherMethodUnderTest
}
```

If the suite tests a single method throughout, MARK grouping can be omitted. The first group of tests (before any MARK) is implicitly the leading concern — add a MARK when a second distinct grouping begins.

`MockHTTPClient` and other test support types are conformances (not test suites) — apply Protocol layer rules to them, not Test rules.

**DocC — suite type.**
Brief — the `@Suite` label already names it:
```swift
/// Tests for `SecurityService`.
@Suite("SecurityService Tests")
struct SecurityServiceTests { ... }
```

**DocC — factory/setup methods.**
Document what they create and any notable configuration:
```swift
/// Creates a `SecurityService` wired to the shared `MockHTTPClient`.
private func makeService() -> SecurityService { ... }

/// Creates an in-memory `ModelContainer` with the alert model types registered.
private func makeContainer() throws -> ModelContainer { ... }
```

**DocC — `@Test` functions.**
One line describing the scenario. The function name is the primary description; the doc comment adds the "given/when" context the name omits:
```swift
/// Verifies that a 403 response causes all three counts to be returned as `nil`.
@Test func fetchMetricsHandlesForbidden() async { ... }

/// Verifies that a second sync replaces previously persisted alerts rather than appending.
@Test func syncDependabotAlertsReplacesExistingAlerts() async throws { ... }
```

**`@MainActor` on a suite.**
Add an inline comment if the reason isn't obvious from context:
```swift
@MainActor // Required because sync methods are @MainActor
struct SecurityServiceTests { ... }
```

---

## Part 7: File Organization Reference

### Layer → Rules mapping

| File location | Layer rules |
|---|---|
| `Focus/Services/*.swift` | Services |
| `Focus/Models/*.swift` (`@Model` classes) | Models — SwiftData |
| `Focus/Models/*.swift` (structs/enums) | Models — Value types (no Relationships section) |
| `Focus/Views/**/*.swift` | Views |
| `Focus/FocusApp.swift` | Views (composition root — document DI setup alongside view rules) |
| `Focus/Networking/*.swift` | Protocols + Concrete Conformances |
| `Focus/Queries/*.swift` | Protocols (enum namespaces — type doc + static property docs) |
| `Focus/Utilities/*.swift` | Services (logic-bearing utilities) |
| `Focus/Extensions/*.swift` | Minimal — type-level doc + doc on each added symbol |
| `FocusTests/**/*Tests.swift` | Tests |
| `FocusTests/Mocks/*.swift` | Protocols + Concrete Conformances |

### Views directory structure

Views are organized into per-tab subdirectories. Place new view files in the correct location:

```
Focus/Views/
├── (shared/cross-tab views)
├── Reports/        # Reports tab
├── Repositories/   # Repositories tab
├── Settings/       # Settings tab
└── Teams/          # Teams tab
```

### Property order within views

```
let inputs          // required data passed from parent
@Environment        // ambient dependencies
@Query              // SwiftData fetch descriptors
@State              // local UI state
```

### Section order summary (all layers)

```
Properties → Init → [layer-specific middle] → Private
```

Private file-scope types always appear below the main type, under their own `// MARK: -` header.
