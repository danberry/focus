# CLAUDE.md

## Project Overview

**focus** is an iOS/Swift application project. The repository is in early development.

## Repository Structure

```
.
├── Focus.xcodeproj/          # Xcode project file
├── Focus/                    # App source code
│   ├── FocusApp.swift        # App entry point (@main)
│   ├── ContentView.swift     # Root SwiftUI view
│   └── Assets.xcassets/      # Asset catalog (icons, colors)
├── FocusTests/               # Unit tests (Swift Testing)
│   └── ContentViewTests.swift
├── .gitignore
├── README.md
└── CLAUDE.md
```

## Tech Stack

- **Language**: Swift 6
- **Platform**: iOS 26 (Apple ecosystem)
- **IDE**: Xcode 26
- **Package Management**: Swift Package Manager (SPM) preferred; CocoaPods and Carthage supported via .gitignore
- **Build System**: Xcode / xcodebuild

## Development Setup

1. Open the Xcode project/workspace in Xcode
2. Select the appropriate scheme and simulator/device
3. Build with `Cmd+B` or run with `Cmd+R`

### CLI Build & Test

```bash
# Build
xcodebuild -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run tests
xcodebuild -scheme Focus -destination 'platform=iOS Simulator,name=iPhone 17' test

# Clean
xcodebuild clean
```

## Git Workflow

- **Main branch**: `develop`
- Feature branches are created off `develop`
- Commit messages should be clear and descriptive
- Keep commits focused on single logical changes

## Swift Conventions

- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use Swift's strong type system; avoid `Any` where possible
- Prefer `let` over `var`
- Use meaningful, descriptive names for types, methods, and variables
- Use access control (`private`, `internal`, `public`) appropriately
- Organize files with `// MARK: -` sections
- Use Swift concurrency (`async`/`await`) for asynchronous code

## Testing

- Use the **Swift Testing** framework (`import Testing`), not XCTest
- Use `@Test` functions and `#expect` / `#require` macros for assertions
- Use `@Suite` to group related tests
- Test files should mirror the source structure with a `Tests` suffix
- Aim for meaningful test coverage on business logic

## Notes for AI Assistants

- The project uses SwiftUI with the `@main` App protocol (no AppDelegate/SceneDelegate)
- Deployment target is iOS 26.0
- Bundle identifier: `com.danberry.Focus`
- The .gitignore is configured for Swift/Xcode development with support for SPM, CocoaPods, Carthage, and fastlane
- When adding new files, follow iOS project conventions (group by feature or layer)
- Do not commit Xcode user-specific data (`xcuserdata/`)
