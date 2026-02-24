We want to overcome the following limitations of XCUITest for testing Swift UIs: serial test runs (due to reliance on Apple Automaton), machine‑locking XCUITests and the need for “pseudo‑e2e” flows). SwiftUIFLowTesting combines SnapshotTesting with a small custom harness around your SwiftUI views and app state, plus a few targeted XCUITests pre‑release.[1][2][3]

## 1. Reframe the goal: “inside‑the‑process” flows

Instead of driving the real app via Apple’s automation layer, model UI flows as **pure Swift** interactions:

- Represent app state in one or more observable objects (e.g. `AppModel`, `ScreenViewModel`) with methods that correspond to user actions (button taps, menu selections, navigation changes).[4]
- In tests, you construct the model, call those methods directly, then render the SwiftUI view hierarchy for that state and assert on:
  - A snapshot image (visual correctness) using **SnapshotTesting**.[2][3][1]
  - The presence/absence of specific text or accessibility labels using view inspection or derived properties (see below).

This gives you “pseudo‑e2e” coverage entirely **inside the process**, so tests are fast, parallelizable, and don’t seize your Mac.

## 2. SnapshotTesting as the rendering engine

SnapshotTesting already supports capturing SwiftUI views as images without launching the app.[3][1][2]

Typical pattern:

```swift
import XCTest
import SnapshotTesting
import SwiftUI
@testable import MyApp

final class ProfileViewTests: XCTestCase {
  func testProfile_loaded() {
	let model = ProfileModel(user: .fixtureLoaded)
	let view = ProfileView(model: model)

	assertSnapshot(of: view, as: .image(layout: .device(config: .iPhoneX)))
  }
}
```

Key points from existing guides:[1][2][3]

- Mark tests or helpers `@MainActor` for SwiftUI rendering.[1]
- Use DI to avoid real side effects in `.onAppear` etc.; inject stub services or pre‑populated models.[5][1]
- Extract modal sheet content into separate views and snapshot those directly, since `.sheet` itself isn’t captured.[1]

This alone solves your **rendering** question pretty cleanly.

## 3. Adding interaction flows without XCUITest

To layer “interaction” on top, you don’t need real gesture injection; you need a thin DSL that calls view‑model methods in the same sequence a user would.

Example pattern:

```swift
@MainActor
final class CheckoutFlowTests: XCTestCase {
  func test_happyPath() {
	let model = CheckoutModel(cart: .fixtureMultipleItems)
	let view = CheckoutView(model: model)

	// 1. Initial state
	assertSnapshot(of: view, as: .image, named: "step1_cart")

	// 2. User taps "Proceed to payment"
	model.proceedToPayment()
	assertSnapshot(of: view, as: .image, named: "step2_payment")

	// 3. User confirms order
	model.confirmOrder()
	assertSnapshot(of: view, as: .image, named: "step3_confirmation")
  }
}
```

Here, `proceedToPayment()` and `confirmOrder()` are **exactly what your button actions call** in the real app; in the view:

```swift
Button("Proceed to payment") {
  model.proceedToPayment()
}
```

You’ve now turned full flows into cheap, parallelizable tests that don’t require XCUITest, yet track UI changes across multiple steps via snapshots.[6][2][3]

## 4. Verifying behavior beyond snapshots

Snapshots are great for layout/regressions but you often want behavioral assertions too. Some common strategies:

- **Public API on view models**: After calling actions, assert on model state directly (e.g. `XCTAssertEqual(model.screen, .confirmation)`).[4]
- **Derived properties for important UI facts**: e.g. `var isCheckoutButtonEnabled: Bool` on the model; views bind `disabled(!model.isCheckoutButtonEnabled)`, and tests assert on the property instead of inspecting the view tree.  
- **View inspection libraries** (optional): Libraries like ViewInspector let you traverse SwiftUI view trees and assert on the presence of text/buttons, but many teams stick with view‑model assertions to avoid brittle structure coupling.[4]

This keeps your “pseudo‑e2e” tests deterministic and fast while still giving you confidence that interactions produce the right state.

## 5. Solving the “hours‑long, takes over Mac” problem

For the rare cases where you still want XCUITest:

- **Keep the suite tiny**: Only a handful of “true e2e” tests that validate integration with the system (window focus, menus, real keyboard shortcuts, etc.). Everything else moves to snapshot + flow tests as above.  
- **Parallelize what you can**:
  - For logic + snapshot tests, use regular XCTest or **Swift Testing**, which is designed for parallel execution on multiple cores and can keep the Mac usable while tests run.[7][2]
  - If you truly need some UI automation, tools like **Bluepill** (for iOS) and **SBTUITestTunnel** show patterns for running UI suites in parallel simulators and isolating state; the same architectural idea (dedicated “test” app target, test‑only flags, mocks injected from the test process) can be applied to your macOS app to keep e2e runs constrained and CI‑only.[8][9]

In practice you’d run:

- Fast snapshot + flow tests **locally** all the time.  
- A small XCUITest suite **on CI only**, maybe nightly or pre‑release.

## 6. Rolling your own mini framework

Given your background, building a very small domain‑specific layer around this is straightforward and worthwhile:

- Define a `FlowTester` that:
  - Accepts a `ViewModel` factory and a sequence of “steps” (`.action { $0.proceedToPayment() }`, `.snapshot("afterPayment")`, etc.).  
  - Exposes one main `run()` that wires model + view + SnapshotTesting for you.
- Add helpers for:
  - Creating views with test‑specific environment (locale, color scheme, dynamic type).[2]
  - Injecting fixed test data and service stubs via environment values or initializers.

You’d end up with test code that looks like:

```swift
FlowTester(CheckoutModel(cart: .fixtureMultipleItems)) { model in
  CheckoutView(model: model)
}
.step("cart")    { _ in }                      // no action, just initial
.step("payment") { $0.proceedToPayment() }
.step("done")    { $0.confirmOrder() }
.run()
```

Under the hood this uses `assertSnapshot` for each step and any additional assertions you define.

***

If you want, describe one concrete flow in your current macOS SwiftUI app (e.g. “open project → add item → save”), and I can sketch the exact view‑model API and test code for a pseudo‑e2e suite that avoids XCUITest entirely for day‑to‑day work.

Sources
[1] I tried snapshot testing for SwiftUI without launching the app using ... https://dev.classmethod.jp/en/articles/swift-snapshot-testing/
[2] GitHub - pointfreeco/swift-snapshot-testing https://github.com/pointfreeco/swift-snapshot-testing
[3] SwiftUI Snapshot Testing - TrozWare https://troz.net/post/2020/swiftui_snapshots/
[4] Writing testable code when using SwiftUI - Swift by Sundell https://www.swiftbysundell.com/articles/writing-testable-code-when-using-swiftui
[5] Snapshot testing in iOS: testing the UI and beyond - Bitrise Blog https://bitrise.io/blog/post/snapshot-testing-in-ios-testing-the-ui-and-beyond
[6] Video #86: SwiftUI Snapshot Testing - Point-Free https://www.pointfree.co/episodes/ep86-swiftui-snapshot-testing
[7] Running tests serially or in parallel - Swift Forums https://forums.swift.org/t/running-tests-serially-or-in-parallel/72935
[8] Subito-it/SBTUITestTunnel: Enable network mocks and ... - GitHub https://github.com/Subito-it/SBTUITestTunnel
[9] Bluepill Alternatives - UI Testing - Awesome iOS - LibHunt https://ios.libhunt.com/bluepill-alternatives
[10] Top 7 Alternatives to XCUITest for Swift/Objective‑C Testing https://testdriver.ai/articles/top-7-alternatives-to-xcuitest-for-swift-objective-c-testing
[11] 5 Automated Mobile App Testing Tools and Frameworks - Maestro https://maestro.dev/insights/automated-mobile-app-testing-tools-frameworks
[12] Running XC UI tests in parallel on device - Stack Overflow https://stackoverflow.com/questions/53062254/running-xc-ui-tests-in-parallel-on-device
[13] Snapshot Testing Tutorial for SwiftUI: Getting Started - Kodeco https://www.kodeco.com/24426963-snapshot-testing-tutorial-for-swiftui-getting-started
[14] Top 5 iOS UI testing frameworks in 2021 - Mailosaur https://mailosaur.com/blog/top-5-ios-ui-testing-frameworks-in-2021
[15] The ultimate guide to unit and UI testing for beginners in Swift - Bitrise https://bitrise.io/blog/post/the-ultimate-guide-to-unit-and-ui-testing-for-beginners-in-swift

