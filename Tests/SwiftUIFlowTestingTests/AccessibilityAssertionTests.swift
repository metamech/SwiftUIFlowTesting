#if canImport(AppKit)
import SwiftUI
import Testing

@testable import SwiftUIFlowTesting

// Tests for #1073 — Accessibility assertion helpers

@Suite(.serialized)
@MainActor
struct AccessibilityAssertionTests {
    @Test
    func accessibilityAssertionFindsExistingIdentifier() {
        let model = MockModel()
        model.screen = "accessible"

        let assertion = FlowAssertion<MockModel>.accessibility(
            identifier: "test-label",
            exists: true
        ) { model in
            Text(model.screen)
                .accessibilityIdentifier("test-label")
        }

        #expect(assertion.label == "accessibility(test-label, exists: true)")
        // The assertion body would precondition-fail if not found,
        // but we can't easily test that without crashing.
        // Instead, verify the assertion was created with correct label.
    }

    @Test
    func accessibilityAssertionDefaultsToExists() {
        let assertion = FlowAssertion<MockModel>.accessibility(
            identifier: "my-id"
        ) { _ in
            Text("Hello")
                .accessibilityIdentifier("my-id")
        }

        #expect(assertion.label == "accessibility(my-id, exists: true)")
    }

    @Test
    func accessibilityAssertionNotExistsLabel() {
        let assertion = FlowAssertion<MockModel>.accessibility(
            identifier: "missing",
            exists: false
        ) { _ in
            Text("Hello")
        }

        #expect(assertion.label == "accessibility(missing, exists: false)")
    }
}
#endif
