import SwiftUI
@testable import SwiftUIFlowTesting

/// A minimal FlowModel for testing.
@Observable
final class MockModel: FlowModel {
    var screen: String = "initial"
    var actionCount = 0

    func advance(to screen: String) {
        self.screen = screen
        actionCount += 1
    }
}

/// A trivial view for testing FlowTester.
struct MockView: View {
    let model: MockModel

    var body: some View {
        Text(model.screen)
    }
}
