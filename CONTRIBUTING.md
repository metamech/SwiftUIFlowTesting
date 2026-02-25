# Contributing to SwiftUIFlowTesting

Thanks for your interest in contributing! This document covers the process for reporting bugs and submitting pull requests.

## Reporting Bugs

Please open a GitHub issue with:

- **Swift version** (`swift --version`)
- **Platform and OS version** (e.g., macOS 15.2, iOS 18.1)
- **Minimal reproduction** — a code snippet or test case that demonstrates the issue
- **Expected vs. actual behavior**

## Pull Request Process

1. **Fork** the repository and create a branch: `<type>/<slug>` (e.g., `feature/async-assertions`, `fix/sendable-conformance`)
2. **Write tests first** — add a failing test, then implement
3. **Run quality gates** before committing:

```bash
swift-format .       # apply formatting
swift build          # must compile
swift test           # all tests must pass
swiftlint            # must pass (if installed)
```

4. **Open a PR** against `main` with a clear description of what changed and why

## Code Style

- **Formatting**: [swift-format](https://github.com/swiftlang/swift-format) with the project's `.swift-format` configuration
- **Linting**: [SwiftLint](https://github.com/realm/SwiftLint) with the project's `.swiftlint.yml`
- **Testing**: [Swift Testing](https://developer.apple.com/documentation/testing) (`@Test`, `@Suite`, `#expect`) — no XCTest

## Package Boundary Rules

- `Sources/` must **never** import XCTest, SnapshotTesting, or any external package
- `Tests/` uses Swift Testing only
- Consuming apps wire SnapshotTesting into the snapshot closure at the call site

## Code of Conduct

Be respectful and constructive. We follow the [Swift.org Code of Conduct](https://www.swift.org/code-of-conduct/).
