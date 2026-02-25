import SwiftUI
@_spi(Experimental) @testable import SwiftUIFlowTesting
import Testing

@Suite("FlowTester")
@MainActor
struct FlowTesterTests {

    // MARK: - Step Building

    @Test func startsWithZeroSteps() {
        let model = MockModel()
        let tester = FlowTester(model: model) { m in MockView(model: m) }
        #expect(tester.stepCount == 0)
        #expect(tester.stepNames.isEmpty)
    }

    @Test func stepBuildingChainsCorrectly() {
        let model = MockModel()
        let tester = FlowTester(model: model) { m in MockView(model: m) }
            .step("first") { _ in }
            .step("second") { _ in }
            .step("third") { _ in }

        #expect(tester.stepCount == 3)
        #expect(tester.stepNames == ["first", "second", "third"])
    }

    @Test func modelIsAccessible() {
        let model = MockModel()
        model.screen = "custom"
        let tester = FlowTester(model: model) { m in MockView(model: m) }
        #expect(tester.model.screen == "custom")
    }

    // MARK: - Execution Order

    @Test func stepsExecuteInOrder() {
        let model = MockModel()
        var executionOrder: [String] = []

        FlowTester(model: model) { m in MockView(model: m) }
            .step("step-1") { _ in executionOrder.append("action-1") }
            .step("step-2") { _ in executionOrder.append("action-2") }
            .step("step-3") { _ in executionOrder.append("action-3") }
            .run { _, _ in }

        #expect(executionOrder == ["action-1", "action-2", "action-3"])
    }

    @Test func actionsCalledPerStep() {
        let model = MockModel()

        FlowTester(model: model) { m in MockView(model: m) }
            .step("first") { $0.advance(to: "screen-1") }
            .step("second") { $0.advance(to: "screen-2") }
            .run { _, _ in }

        #expect(model.actionCount == 2)
        #expect(model.screen == "screen-2")
    }

    // MARK: - Snapshot Closure

    @Test func snapshotClosureInvokedWithCorrectNames() {
        let model = MockModel()
        var snapshotNames: [String] = []

        FlowTester(model: model) { m in MockView(model: m) }
            .step("cart") { _ in }
            .step("payment") { _ in }
            .step("confirmation") { _ in }
            .run { name, _ in
                snapshotNames.append(name)
            }

        #expect(snapshotNames == ["cart", "payment", "confirmation"])
    }

    @Test func snapshotReceivesAnyView() {
        let model = MockModel()
        var receivedView = false

        FlowTester(model: model) { m in MockView(model: m) }
            .step("check") { _ in }
            .run { _, view in
                // AnyView is received — just verify it doesn't crash
                _ = view
                receivedView = true
            }

        #expect(receivedView)
    }

    // MARK: - Assertions

    @Test func assertionsRunAfterAction() {
        let model = MockModel()
        var assertionOrder: [String] = []

        FlowTester(model: model) { m in MockView(model: m) }
            .step("advance") { model in
                model.advance(to: "next")
                assertionOrder.append("action")
            } assert: { _ in
                assertionOrder.append("assert")
            }
            .run { _, _ in }

        #expect(assertionOrder == ["action", "assert"])
    }

    @Test func multipleAssertionsPerStep() {
        let model = MockModel()
        var assertionLabels: [String] = []

        FlowTester(model: model) { m in MockView(model: m) }
            .step(
                "multi",
                assertions: [
                    FlowAssertion("first") { _ in assertionLabels.append("first") },
                    FlowAssertion("second") { _ in assertionLabels.append("second") },
                    FlowAssertion("third") { _ in assertionLabels.append("third") },
                ]
            )
            .run { _, _ in }

        #expect(assertionLabels == ["first", "second", "third"])
    }

    @Test func assertionSeesModelAfterAction() {
        let model = MockModel()

        FlowTester(model: model) { m in MockView(model: m) }
            .step(
                "advance",
                action: { $0.advance(to: "payment") },
                assert: { model in #expect(model.screen == "payment") }
            )
            .run { _, _ in }
    }

    // MARK: - Empty Steps

    @Test func emptyStepsWork() {
        let model = MockModel()
        let results = FlowTester(model: model) { m in MockView(model: m) }
            .run { _, _ in }

        #expect(results.isEmpty)
    }

    @Test func stepWithNoActionOrAssertions() {
        let model = MockModel()
        var snapshotCount = 0

        FlowTester(model: model) { m in MockView(model: m) }
            .step("idle") { _ in }
            .run { _, _ in snapshotCount += 1 }

        #expect(snapshotCount == 1)
        #expect(model.screen == "initial")
    }

    // MARK: - Results

    @Test func runReturnsResults() {
        let model = MockModel()
        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("first") { _ in }
            .step("second") { _ in }
            .run { _, _ in }

        #expect(results.count == 2)
        #expect(results[0].stepName == "first")
        #expect(results[0].resolvedName == "first")
        #expect(results[0].index == 0)
        #expect(results[0].assertionCount == 0)
        #expect(results[0].configurationLabel == nil)
        #expect(results[1].stepName == "second")
        #expect(results[1].resolvedName == "second")
        #expect(results[1].index == 1)
    }

    // MARK: - Configuration

    @Test func configurationIsStored() {
        let model = MockModel()
        let config = FlowConfiguration { env in
            env.colorScheme = .dark
        }
        let tester = FlowTester(model: model, configuration: config) { m in
            MockView(model: m)
        }
        // Verify the stored config applies correctly
        var env = EnvironmentValues()
        tester.configuration.environmentPatch(&env)
        #expect(env.colorScheme == .dark)
    }

    @Test func environmentPatchAppliedDuringRun() {
        let model = MockModel()
        let config = FlowConfiguration { env in
            env.colorScheme = .dark
        }

        var snapshotCalled = false
        FlowTester(model: model, configuration: config) { m in MockView(model: m) }
            .step("dark") { _ in }
            .run { _, _ in
                snapshotCalled = true
            }

        #expect(snapshotCalled)
    }

    // MARK: - Feature 1: Naming & Auto-Step-Naming

    @Test func namedTesterPrefixesStepNames() {
        let model = MockModel()
        let tester = FlowTester(name: "checkout", model: model) { m in MockView(model: m) }
            .step("cart") { _ in }
            .step("payment") { _ in }

        #expect(tester.stepNames == ["checkout-cart", "checkout-payment"])
    }

    @Test func unnamedTesterPreservesStepNames() {
        let model = MockModel()
        let tester = FlowTester(model: model) { m in MockView(model: m) }
            .step("cart") { _ in }

        #expect(tester.stepNames == ["cart"])
    }

    @Test func autoNamedStepsWithTesterName() {
        let model = MockModel()
        let tester = FlowTester(name: "flow", model: model) { m in MockView(model: m) }
            .step { _ in }
            .step { _ in }

        #expect(tester.stepNames == ["flow-step-0", "flow-step-1"])
    }

    @Test func autoNamedStepsWithoutTesterName() {
        let model = MockModel()
        let tester = FlowTester(model: model) { m in MockView(model: m) }
            .step { _ in }
            .step { _ in }

        #expect(tester.stepNames == ["step-0", "step-1"])
    }

    @Test func resolvedNameInSnapshotClosure() {
        let model = MockModel()
        var snapshotNames: [String] = []

        FlowTester(name: "login", model: model) { m in MockView(model: m) }
            .step("form") { _ in }
            .step { _ in }
            .run { name, _ in
                snapshotNames.append(name)
            }

        #expect(snapshotNames == ["login-form", "login-step-1"])
    }

    @Test func resolvedNameInResults() {
        let model = MockModel()
        let results = FlowTester(name: "test", model: model) { m in MockView(model: m) }
            .step("a") { _ in }
            .step { _ in }
            .run { _, _ in }

        #expect(results[0].stepName == "a")
        #expect(results[0].resolvedName == "test-a")
        #expect(results[1].stepName == "")
        #expect(results[1].resolvedName == "test-step-1")
    }

    // MARK: - Feature 4: Result Enrichment

    @Test func resultIncludesDuration() {
        let model = MockModel()
        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("timed") { _ in }
            .run { _, _ in }

        #expect(results[0].duration >= .zero)
    }

    @Test func resultIncludesAssertionCount() {
        let model = MockModel()
        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("no-assert") { _ in }
            .step("one-assert", action: { _ in }, assert: { _ in })
            .step(
                "two-asserts",
                assertions: [
                    FlowAssertion("a") { _ in },
                    FlowAssertion("b") { _ in },
                ]
            )
            .run { _, _ in }

        #expect(results[0].assertionCount == 0)
        #expect(results[1].assertionCount == 1)
        #expect(results[2].assertionCount == 2)
    }

    // MARK: - Feature 5: Lifecycle Hooks

    @Test func beforeEachStepHookCalled() {
        let model = MockModel()
        var hookOrder: [String] = []

        FlowTester(model: model) { m in MockView(model: m) }
            .beforeEachStep { _, _, _ in hookOrder.append("before") }
            .step("a") { _ in hookOrder.append("action") }
            .run { _, _ in }

        #expect(hookOrder == ["before", "action"])
    }

    @Test func afterEachStepHookCalled() {
        let model = MockModel()
        var hookOrder: [String] = []

        FlowTester(model: model) { m in MockView(model: m) }
            .afterEachStep { _, _, _ in hookOrder.append("after") }
            .step(
                "a",
                action: { _ in },
                assert: { _ in hookOrder.append("assert") }
            )
            .run { _, _ in }

        #expect(hookOrder == ["assert", "after"])
    }

    @Test func hookReceivesResolvedNameAndIndex() {
        let model = MockModel()
        var received: [(String, Int)] = []

        FlowTester(name: "flow", model: model) { m in MockView(model: m) }
            .beforeEachStep { name, index, _ in received.append((name, index)) }
            .step("a") { _ in }
            .step { _ in }
            .run { _, _ in }

        #expect(received[0].0 == "flow-a")
        #expect(received[0].1 == 0)
        #expect(received[1].0 == "flow-step-1")
        #expect(received[1].1 == 1)
    }

    @Test func hookExecutionOrder() {
        let model = MockModel()
        var order: [String] = []

        FlowTester(model: model) { m in MockView(model: m) }
            .beforeEachStep { _, _, _ in order.append("before") }
            .afterEachStep { _, _, _ in order.append("after") }
            .step(
                "s",
                action: { _ in order.append("action") },
                assert: { _ in order.append("assert") }
            )
            .run { _, _ in order.append("snapshot") }

        #expect(order == ["before", "action", "snapshot", "assert", "after"])
    }

    // MARK: - Feature 2: Async Steps

    @Test func asyncStepExecutesAction() async {
        let model = MockModel()

        await FlowTester(model: model) { m in MockView(model: m) }
            .asyncStep("fetch") { model in
                model.advance(to: "loaded")
            }
            .asyncRun { _, _ in }

        #expect(model.screen == "loaded")
    }

    @Test func asyncRunFallsBackToSyncAction() async {
        let model = MockModel()

        await FlowTester(model: model) { m in MockView(model: m) }
            .step("sync") { $0.advance(to: "synced") }
            .asyncRun { _, _ in }

        #expect(model.screen == "synced")
    }

    @Test func asyncRunMixesSyncAndAsyncSteps() async {
        let model = MockModel()
        var order: [String] = []

        await FlowTester(model: model) { m in MockView(model: m) }
            .step("sync") { _ in order.append("sync") }
            .asyncStep("async") { _ in order.append("async") }
            .step("sync2") { _ in order.append("sync2") }
            .asyncRun { _, _ in }

        #expect(order == ["sync", "async", "sync2"])
    }

    @Test func asyncStepWithAssertion() async {
        let model = MockModel()

        await FlowTester(model: model) { m in MockView(model: m) }
            .asyncStep("fetch") { model in
                model.advance(to: "fetched")
            } assert: { model in
                #expect(model.screen == "fetched")
            }
            .asyncRun { _, _ in }
    }

    @Test func asyncRunReturnsResults() async {
        let model = MockModel()
        let results = await FlowTester(model: model) { m in MockView(model: m) }
            .asyncStep("fetch") { _ in }
            .asyncRun { _, _ in }

        #expect(results.count == 1)
        #expect(results[0].stepName == "fetch")
        #expect(results[0].duration >= .zero)
    }

    // MARK: - Feature 3: Matrix Runs

    @Test func matrixRunExecutesPerConfiguration() {
        let model = MockModel()
        var snapshotNames: [String] = []

        let configs = [
            FlowConfiguration(label: "light") { _ in },
            FlowConfiguration(label: "dark") { env in env.colorScheme = .dark },
        ]

        FlowTester(name: "checkout", model: model) { m in MockView(model: m) }
            .step("cart") { _ in }
            .step("payment") { _ in }
            .matrixRun(
                configurations: configs,
                modelFactory: { MockModel() },
                snapshot: { name, _ in snapshotNames.append(name) }
            )

        #expect(
            snapshotNames == [
                "checkout-cart-light",
                "checkout-payment-light",
                "checkout-cart-dark",
                "checkout-payment-dark",
            ]
        )
    }

    @Test func matrixRunUsesModelFactory() {
        let model = MockModel()

        let configs = [
            FlowConfiguration(label: "a") { _ in },
            FlowConfiguration(label: "b") { _ in },
        ]

        FlowTester(model: model) { m in MockView(model: m) }
            .step("advance") { $0.advance(to: "done") }
            .matrixRun(
                configurations: configs,
                modelFactory: { MockModel() },
                snapshot: { _, _ in }
            )

        // Original model is untouched
        #expect(model.screen == "initial")
    }

    @Test func matrixRunResultsHaveConfigurationLabel() {
        let model = MockModel()

        let configs = [
            FlowConfiguration(label: "dark") { _ in }
        ]

        let results = FlowTester(model: model) { m in MockView(model: m) }
            .step("s") { _ in }
            .matrixRun(
                configurations: configs,
                modelFactory: { MockModel() },
                snapshot: { _, _ in }
            )

        #expect(results[0].configurationLabel == "dark")
    }

    // MARK: - Feature 6: Composition

    @Test func extractedStepsReturnsSteps() {
        let model = MockModel()
        let tester = FlowTester(model: model) { m in MockView(model: m) }
            .step("a") { _ in }
            .step("b") { _ in }

        let extracted = tester.extractedSteps
        #expect(extracted.count == 2)
        #expect(extracted[0].name == "a")
        #expect(extracted[1].name == "b")
    }

    @Test func stepsMethodAddsSteps() {
        let model = MockModel()

        let preflight = FlowTester(model: model) { m in MockView(model: m) }
            .step("login") { _ in }
            .extractedSteps

        let tester = FlowTester(model: model) { m in MockView(model: m) }
            .steps(preflight)
            .step("dashboard") { _ in }

        #expect(tester.stepCount == 2)
        #expect(tester.stepNames == ["login", "dashboard"])
    }

    @Test func composedStepsRenumberCorrectly() {
        let model = MockModel()

        let shared = FlowTester(model: model) { m in MockView(model: m) }
            .step { _ in }  // unnamed
            .extractedSteps

        let tester = FlowTester(name: "flow", model: model) { m in MockView(model: m) }
            .step("intro") { _ in }
            .steps(shared)
            .step { _ in }

        // "intro" at index 0, unnamed at index 1, unnamed at index 2
        #expect(tester.stepNames == ["flow-intro", "flow-step-1", "flow-step-2"])
    }

    @Test func composedStepsExecuteActions() {
        let model = MockModel()
        var actions: [String] = []

        let shared = FlowTester(model: model) { m in MockView(model: m) }
            .step("shared") { _ in actions.append("shared") }
            .extractedSteps

        FlowTester(model: model) { m in MockView(model: m) }
            .steps(shared)
            .step("local") { _ in actions.append("local") }
            .run { _, _ in }

        #expect(actions == ["shared", "local"])
    }
}
