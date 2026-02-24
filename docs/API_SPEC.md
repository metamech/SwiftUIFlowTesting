
***

## 1. Package overview

**Package name** (example): `SwiftUIFlowTesting`

Targets:

- Library target: `SwiftUIFlowTesting`
- Test-only dependencies (in clients): `XCTest`, `SnapshotTesting`

Primary responsibilities:

- Provide a generic **flow runner** (`FlowTester`) that:
  - Owns a *model* (view model / app model).
  - Creates a SwiftUI view from that model.
  - Advances the model through steps (simulating interactions).
  - Captures snapshots and exposes hook points for assertions.

The package itself should not depend on the app; instead, apps conform to a couple of simple protocols.

***

## 2. Core protocols and types

### 2.1 Model and view factory

You want to be able to plug in *any* model + view pair. A minimal protocol surface:

```swift
import SwiftUI

/// Marker for models that drive a SwiftUI screen or flow.
public protocol FlowModel: AnyObject {}

/// Something that knows how to build a SwiftUI view for a given model.
public protocol FlowViewFactory {
	associatedtype Model: FlowModel
	associatedtype Content: View

	@MainActor
	func makeView(for model: Model) -> Content
}
```

For convenience, you can also offer a simple closure-based wrapper:

```swift
public struct ClosureFlowViewFactory<M: FlowModel, V: View>: FlowViewFactory {
	public typealias Model = M
	public typealias Content = V

	private let builder: (M) -> V

	public init(builder: @escaping (M) -> V) {
		self.builder = builder
	}

	@MainActor
	public func makeView(for model: M) -> V {
		builder(model)
	}
}
```

App code doesn’t have to know about the details; it can just pass a closure that builds the view from the model.

***

## 3. FlowTester API

The main type users interact with:

```swift
import SwiftUI

public struct FlowStep<Model: FlowModel> {
	public let name: String
	public let action: @MainActor (Model) -> Void
	public let assert: (@MainActor (Model) -> Void)?

	public init(
		name: String,
		action: @escaping @MainActor (Model) -> Void,
		assert: (@escaping @MainActor (Model) -> Void)? = nil
	) {
		self.name = name
		self.action = action
		self.assert = assert
	}
}

public final class FlowTester<Factory: FlowViewFactory> {
	public typealias Model = Factory.Model

	private let factory: Factory
	private let model: Model
	private var steps: [FlowStep<Model>] = []

	public init(model: Model, viewFactory: Factory) {
		self.model = model
		self.factory = viewFactory
	}

	@discardableResult
	public func step(
		_ name: String,
		action: @escaping @MainActor (Model) -> Void = { _ in },
		assert: (@escaping @MainActor (Model) -> Void)? = nil
	) -> Self {
		steps.append(.init(name: name, action: action, assert: assert))
		return self
	}

	@MainActor
	public func run(
		snapshot: (String, AnyView) -> Void
	) {
		for step in steps {
			step.action(model)
			let view = AnyView(factory.makeView(for: model))
			snapshot(step.name, view)
			step.assert?(model)
		}
	}
}
```

Note: `snapshot` is a closure the **test target** will provide (e.g. wrapping `SnapshotTesting.assertSnapshot`).

***

## 4. Integration from an app’s tests

In your app’s test target (not in the package), you wire it up with `XCTest` + `SnapshotTesting`.

Example for a `CheckoutModel` and `CheckoutView`:

```swift
import XCTest
import SwiftUI
import SnapshotTesting
import SwiftUIFlowTesting
@testable import MyApp

@MainActor
final class CheckoutFlowTests: XCTestCase {

	func test_happyPath_checkout_flow() {
		let model = CheckoutModel(cart: .fixtureMultipleItems)

		let factory = ClosureFlowViewFactory<CheckoutModel, CheckoutView> { model in
			CheckoutView(model: model)
		}

		let tester = FlowTester(model: model, viewFactory: factory)

		tester
			.step("cart") { _ in
				// initial state
			} assert: { model in
				XCTAssertEqual(model.screen, .cart)
			}
			.step("payment") { model in
				model.proceedToPayment()
			} assert: { model in
				XCTAssertEqual(model.screen, .payment)
			}
			.step("confirmation") { model in
				model.confirmOrder()
			} assert: { model in
				XCTAssertEqual(model.screen, .confirmation)
			}
			.run { name, view in
				assertSnapshot(
					of: view,
					as: .image(layout: .device(config: .iPhoneX)),
					named: name
				)
			}
	}
}
```

From the package’s perspective, it just calls the `snapshot` closure; the test target decides how to snapshot (image, text, dark mode, etc.).

***

## 5. Expectations on app-side models & views

To keep the package reusable, define **minimal conventions** apps must follow:

### 5.1 Models

- Conform to `FlowModel` (empty marker) to opt into the system:

```swift
final class CheckoutModel: ObservableObject, FlowModel {
	@Published var screen: Screen
	@Published var isSubmitButtonEnabled: Bool
	// ...

	func proceedToPayment() { /* ... */ }
	func confirmOrder() { /* ... */ }
}
```

- Expose **intent methods** that correspond to UI actions:
  - No direct side effects in SwiftUI button closures.
  - Button closures call these methods.

### 5.2 Views

- Have initializers that take a model instance:

```swift
struct CheckoutView: View {
	@ObservedObject var model: CheckoutModel

	var body: some View {
		// ...
	}
}
```

- Avoid hard‑wiring dependencies inside the view; all interesting state should come from the model (and be assertable).

### 5.3 Test fixtures

You’ll likely create separate **fixture helpers** or test helpers per app:

```swift
extension CheckoutModel {
	static func fixture(cart: Cart = .fixtureMultipleItems) -> CheckoutModel {
		CheckoutModel(cart: cart, paymentService: .stubSuccess)
	}
}
```

Those live in each app’s test target (or a shared `TestSupport` package), not in `SwiftUIFlowTesting`.

***

## 6. Package boundaries and dependencies

### Inside the `SwiftUIFlowTesting` package

- Dependencies: `SwiftUI` and `Foundation` only.
- No direct dependency on `XCTest` or `SnapshotTesting`:
  - Keeps it usable from any test framework (Quick/Nimble, Swift Testing, etc.).
  - The package just exposes the runner and contracts.

### In each app

- Add `SwiftUIFlowTesting` as an SPM dependency.
- In test targets:
  - Depend on:
	- `XCTest`
	- `SnapshotTesting`
	- `SwiftUIFlowTesting`
- Optionally define thin wrappers for snapshotting to keep test code DRY:

```swift
@MainActor
func assertFlowSnapshot(
	_ name: String,
	view: AnyView,
	file: StaticString = #file,
	testName: String = #function,
	line: UInt = #line
) {
	assertSnapshot(
		of: view,
		as: .image(layout: .device(config: .iPhoneX)),
		named: name,
		file: file,
		testName: testName,
		line: line
	)
}
```

Then `FlowTester.run` can call `assertFlowSnapshot`.

***

## 7. Extensibility hooks

To make it more powerful over time without breaking callers:

- Add **configuration** struct:

```swift
public struct FlowConfiguration {
	public var recordSnapshots: Bool
	public var environmentValues: (inout EnvironmentValues) -> Void

	public init(
		recordSnapshots: Bool = false,
		environmentValues: @escaping (inout EnvironmentValues) -> Void = { _ in }
	) {
		self.recordSnapshots = recordSnapshots
		self.environmentValues = environmentValues
	}
}
```

- Pass `FlowConfiguration` into `FlowTester`:

```swift
public final class FlowTester<Factory: FlowViewFactory> {
	public let configuration: FlowConfiguration
	// ...
}
```

- Inside tests, you can configure environment (e.g. dark mode, locale) via this configuration before constructing the view.

***

## 8. Coexisting with rare, full e2e tests

Because the package is purely in-process, it doesn’t conflict with your occasional real e2e/XCUITests:

- Apps keep:
  - `SwiftUIFlowTesting` + snapshot-based flows for all day‑to‑day UI coverage.
  - A tiny, separate XCUITest target for pre‑release / CI.
- Your CLAUDE.md (or equivalent) can instruct:
  - “For UI behavior tests, use `SwiftUIFlowTesting` flows and snapshots.”
  - “Only touch XCUITest when working on system-level concerns.”

***

If you want, I can next sketch an actual `Package.swift` plus a full `FlowTester` implementation file you could paste in as a starting point.

Sources
[1] Modularizing iOS Applications with SwiftUI and Swift Package ... https://nimblehq.co/blog/modern-approach-modularize-ios-swiftui-spm
[2] Creating a standalone Swift package with Xcode - Apple Developer https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode
[3] Make Your SwiftUI Design System Portable with Swift Packages https://async.techconnection.io/talks/frenchkit/swift-connection-2023/vui-nguyen-make-your-swiftui-design-system-portable-with-swift-packages/
[4] Building REUSABLE SwiftUI components | Swift Heroes 2023 Talk https://www.youtube.com/watch?v=PocljzAYFL4
[5] Make Your SwiftUI Design System Portable with Swift Packages https://speakerdeck.com/vuinguyen/make-your-swiftui-design-system-portable-with-swift-packages
[6] Let's build a charting framework - Next Level Swift https://medium.nextlevelswift.com/lets-build-a-charts-framework-edb2f67fca53
[7] Swift Package Manager - SwiftUI Handbook - Design+Code https://designcode.io/swiftui-handbook-swift-package-manager/

