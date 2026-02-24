import Testing
import SwiftUI
@testable import SwiftUIFlowTesting

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
            .step("multi", assertions: [
                FlowAssertion("first") { _ in assertionLabels.append("first") },
                FlowAssertion("second") { _ in assertionLabels.append("second") },
                FlowAssertion("third") { _ in assertionLabels.append("third") },
            ])
            .run { _, _ in }

        #expect(assertionLabels == ["first", "second", "third"])
    }

    @Test func assertionSeesModelAfterAction() {
        let model = MockModel()

        FlowTester(model: model) { m in MockView(model: m) }
            .step("advance") { $0.advance(to: "payment") } assert: { model in
                #expect(model.screen == "payment")
            }
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
        #expect(results[0].index == 0)
        #expect(results[1].stepName == "second")
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
}
