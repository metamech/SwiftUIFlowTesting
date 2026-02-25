import SwiftUI
@_spi(Experimental) @testable import SwiftUIFlowTesting
import Testing

@Suite("FlowStep")
@MainActor
struct FlowStepTests {

    @Test func createsWithNameAndAction() {
        let step = FlowStep<MockModel>(
            name: "test-step",
            action: { $0.advance(to: "next") }
        )

        #expect(step.name == "test-step")
        #expect(step.assertions.isEmpty)
        #expect(step.asyncAction == nil)
    }

    @Test func createsWithAssertions() {
        let step = FlowStep<MockModel>(
            name: "step-with-assertions",
            action: { _ in },
            assertions: [
                FlowAssertion("check screen") { model in
                    #expect(model.screen == "initial")
                }
            ]
        )

        #expect(step.assertions.count == 1)
        #expect(step.assertions[0].label == "check screen")
    }

    @Test func actionMutatesModel() {
        let model = MockModel()
        let step = FlowStep<MockModel>(
            name: "mutate",
            action: { $0.advance(to: "changed") }
        )

        step.action(model)
        #expect(model.screen == "changed")
        #expect(model.actionCount == 1)
    }

    @Test func defaultsToEmptyAssertions() {
        let step = FlowStep<MockModel>(
            name: "no-assertions",
            action: { _ in }
        )

        #expect(step.assertions.isEmpty)
    }

    @Test func createsWithAsyncAction() {
        let step = FlowStep<MockModel>(
            name: "async-step",
            action: { _ in },
            asyncAction: { model in
                model.advance(to: "loaded")
            }
        )

        #expect(step.asyncAction != nil)
    }
}
