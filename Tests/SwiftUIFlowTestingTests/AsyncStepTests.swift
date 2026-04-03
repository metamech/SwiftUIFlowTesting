import SwiftUI
import Testing

@testable import SwiftUIFlowTesting

// Tests for #1071 — Stabilized async APIs (no longer behind @_spi(Experimental))

@Suite(.serialized)
@MainActor
struct AsyncStepTests {
    @Test
    func asyncStepExecutesAsyncAction() async {
        let model = MockModel()

        let results = await FlowTester(name: "async", model: model) { model in
            MockView(model: model)
        }
        .asyncStep("load") { model in
            // Simulate async work
            model.advance(to: "loaded")
        }
        .asyncRun { _, _ in }

        #expect(results.count == 1)
        #expect(results[0].resolvedName == "async-load")
        #expect(model.screen == "loaded")
    }

    @Test
    func asyncStepWithAssertions() async {
        let model = MockModel()

        let results = await FlowTester(name: "async-assert", model: model) { model in
            MockView(model: model)
        }
        .asyncStep("step1", action: { model in
            model.advance(to: "step1")
        }, assertions: [
            FlowAssertion("screen is step1") { model in
                #expect(model.screen == "step1")
            }
        ])
        .asyncRun { _, _ in }

        #expect(results.count == 1)
        #expect(results[0].assertionCount == 1)
    }

    @Test
    func asyncStepWithSingleAssert() async {
        let model = MockModel()

        let results = await FlowTester(name: "async-single", model: model) { model in
            MockView(model: model)
        }
        .asyncStep("step1", action: { model in
            model.advance(to: "done")
        }, assert: { model in
            #expect(model.screen == "done")
        })
        .asyncRun { _, _ in }

        #expect(results.count == 1)
        #expect(results[0].assertionCount == 1)
    }

    @Test
    func asyncRunWithBuiltinSnapshot() async {
        let model = MockModel()

        let results = await FlowTester(name: "async-builtin", model: model) { model in
            MockView(model: model)
        }
        .asyncStep("init") { _ in }
        .asyncRun(snapshotMode: .disabled)

        #expect(results.count == 1)
        #expect(results[0].resolvedName == "async-builtin-init")
    }

    @Test
    func asyncActionPropertyIsPublic() {
        // Verify asyncAction is accessible without @_spi import
        let step = FlowStep<MockModel>(
            name: "test",
            action: { _ in },
            asyncAction: { _ in },
            assertions: [],
            snapshotEnabled: true
        )

        #expect(step.asyncAction != nil)
        #expect(step.name == "test")
    }

    @Test
    func flowStepResultPropertiesArePublic() async {
        let model = MockModel()

        let results = await FlowTester(name: "result", model: model) { model in
            MockView(model: model)
        }
        .asyncStep("timed") { model in
            model.advance(to: "done")
        }
        .asyncRun { _, _ in }

        let result = results[0]
        // These were previously @_spi(Experimental) — now public
        let _ = result.duration
        let _ = result.assertionCount
        let _ = result.configurationLabel
        #expect(result.assertionCount == 0)
        #expect(result.configurationLabel == nil)
    }
}
