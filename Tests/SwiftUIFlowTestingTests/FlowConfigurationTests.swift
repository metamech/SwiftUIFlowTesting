import SwiftUI
import Testing
@testable import SwiftUIFlowTesting

@Suite("FlowConfiguration")
@MainActor
struct FlowConfigurationTests {

    @Test func defaultConfigurationHasNoOpPatch() {
        let config = FlowConfiguration()
        var env = EnvironmentValues()
        config.environmentPatch(&env)
        // Should not crash — no-op patch
    }

    @Test func defaultConfigurationHasEmptyLabel() {
        let config = FlowConfiguration()
        #expect(config.label == "")
    }

    @Test func customPatchAppliesColorScheme() {
        let config = FlowConfiguration { env in
            env.colorScheme = .dark
        }

        var env = EnvironmentValues()
        config.environmentPatch(&env)
        #expect(env.colorScheme == .dark)
    }

    @Test func customPatchAppliesLocale() {
        let config = FlowConfiguration { env in
            env.locale = Locale(identifier: "ja_JP")
        }

        var env = EnvironmentValues()
        config.environmentPatch(&env)
        #expect(env.locale.identifier == "ja_JP")
    }

    @Test func labeledConfiguration() {
        let config = FlowConfiguration(label: "dark") { env in
            env.colorScheme = .dark
        }

        #expect(config.label == "dark")
    }
}
