import Foundation
import Testing
@testable import SwiftUIFlowTesting

@Suite("SnapshotConfiguration")
struct SnapshotConfigurationTests {

    @Test func defaultScale() {
        let config = SnapshotConfiguration()
        #expect(config.scale == 2.0)
    }

    @Test func defaultProposedSize() {
        let config = SnapshotConfiguration()
        #expect(config.proposedSize.width == 390)
        #expect(config.proposedSize.height == 844)
    }

    @Test func defaultRecordIsFalse() {
        // Unless FLOW_RECORD_SNAPSHOTS is set in the env, record defaults to false
        let config = SnapshotConfiguration(record: false)
        #expect(config.record == false)
    }

    @Test func defaultSnapshotDirectoryIsNil() {
        let config = SnapshotConfiguration()
        #expect(config.snapshotDirectory == nil)
    }

    @Test func customValues() {
        let config = SnapshotConfiguration(
            scale: 3.0,
            proposedSize: .init(width: 393, height: 852),
            record: true,
            snapshotDirectory: "/tmp/snaps"
        )
        #expect(config.scale == 3.0)
        #expect(config.proposedSize.width == 393)
        #expect(config.proposedSize.height == 852)
        #expect(config.record == true)
        #expect(config.snapshotDirectory == "/tmp/snaps")
    }
}
