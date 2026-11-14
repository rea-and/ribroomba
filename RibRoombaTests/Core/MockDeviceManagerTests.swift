import XCTest
import RxBlocking
import RxSwift
@testable import RibRoomba

final class MockDeviceManagerTests: XCTestCase {

    private func makeManager(defaults: UserDefaults? = nil) -> MockDeviceManager {
        MockDeviceManager(defaults: defaults, scanStep: .milliseconds(1), pairingDelay: .milliseconds(1), scheduler: testScheduler)
    }

    private func scanResults(_ m: MockDeviceManager) throws -> [[DiscoveredDevice]] {
        try m.scan().toBlocking(timeout: 5).toArray()
    }

    func testScanEmitsGrowingListThenCompletes() throws {
        let results = try scanResults(makeManager())
        XCTAssertEqual(results.first?.count, 0)
        XCTAssertEqual(results.map(\.count), Array(0...MockDeviceManager.nearby.count))
        XCTAssertEqual(results.last, MockDeviceManager.nearby)
    }

    func testAddMakesDevicePairedAndHidesItFromNextScan() throws {
        let m = makeManager()
        let found = MockDeviceManager.nearby[0]
        let device = try m.add(found).toBlocking(timeout: 5).first()
        XCTAssertEqual(device?.id, found.id)
        XCTAssertEqual(try latest(m.pairedDevices), [device!])
        XCTAssertFalse(try scanResults(m).last!.contains(found))
    }

    func testAddingTwiceFails() throws {
        let m = makeManager()
        _ = try m.add(MockDeviceManager.nearby[0]).toBlocking(timeout: 5).first()
        XCTAssertThrowsError(try m.add(MockDeviceManager.nearby[0]).toBlocking(timeout: 5).first()) {
            XCTAssertEqual($0 as? DeviceError, .alreadyAdded)
        }
    }

    func testRemove() throws {
        let m = makeManager()
        let device = try m.add(MockDeviceManager.nearby[1]).toBlocking(timeout: 5).first()!
        try complete(m.remove(device))
        XCTAssertTrue(try latest(m.pairedDevices).isEmpty)
    }

    func testPairedDevicesPersist() throws {
        let suite = UserDefaults(suiteName: "MockDeviceManagerTests-\(UUID().uuidString)")!
        let device = try makeManager(defaults: suite).add(MockDeviceManager.nearby[2]).toBlocking(timeout: 5).first()!
        XCTAssertEqual(try latest(makeManager(defaults: suite).pairedDevices), [device])
    }

    func testConnectorIsCachedPerDeviceAndDroppedOnRemove() throws {
        let m = makeManager()
        let a = try m.add(MockDeviceManager.nearby[0]).toBlocking(timeout: 5).first()!
        let b = try m.add(MockDeviceManager.nearby[1]).toBlocking(timeout: 5).first()!
        XCTAssertTrue(m.connector(for: a) === m.connector(for: a))
        XCTAssertFalse(m.connector(for: a) === m.connector(for: b))
        let old = m.connector(for: a)
        try complete(m.remove(a))
        XCTAssertFalse(old === m.connector(for: a))
    }
}
