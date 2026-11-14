import XCTest
import RxSwift
@testable import RibRoomba

final class MockRobotConnectorTests: XCTestCase {

    private func makeConnector(now: @escaping () -> Date = Date.init, defaults: UserDefaults? = nil,
                               id: String = "t") -> MockRobotConnector {
        MockRobotConnector(deviceID: id, defaults: defaults, now: now, tickInterval: nil,
                           connectDelay: .milliseconds(1), scheduler: testScheduler)
    }

    private func connected(_ c: MockRobotConnector) throws -> MockRobotConnector {
        try complete(c.connect())
        return c
    }

    private func state(_ c: MockRobotConnector) throws -> RobotState { try latest(c.state) }

    func testCommandsFailBeforeConnecting() {
        let c = makeConnector()
        XCTAssertThrowsError(try complete(c.send(.start(.standard)))) { XCTAssertEqual($0 as? RobotError, .notConnected) }
    }

    func testConnectingPublishesConnectedState() throws {
        let c = try connected(makeConnector())
        XCTAssertEqual(try latest(c.connection), .connected)
    }

    func testCleaningDrainsBatteryAndFillsBin() throws {
        let c = try connected(makeConnector())
        try complete(c.send(.start(.standard)))
        c.tick(); c.tick()
        let s = try state(c)
        XCTAssertEqual(s.status, .cleaning)
        XCTAssertEqual(s.batteryPercent, 100 - 2 * MockRobotConnector.drainPerTick)
        XCTAssertEqual(s.binPercent, 10 + 2 * MockRobotConnector.binFillPerTick)
        XCTAssertEqual(s.areaCleaned, 2.0, accuracy: 0.001)
    }

    func testQuickRunCompletesRecordsHistoryAndDocks() throws {
        let c = try connected(makeConnector())
        let before = try latest(c.history).count
        try complete(c.send(.start(.quick)))
        for _ in 0..<8 { c.tick() }  // 8 ticks x 1.5 m² = 12 m² target
        XCTAssertEqual(try state(c).status, .returningToDock)
        let history = try latest(c.history)
        XCTAssertEqual(history.count, before + 1)
        XCTAssertEqual(history.first?.outcome, .completed)
        XCTAssertEqual(history.first?.mode, .quick)
        c.tick()
        XCTAssertEqual(try state(c).status, .charging)
    }

    /// Deep run: the bin (10% + 2%/tick) fills after 45 ticks, long before the battery (-1%/tick) runs low.
    private func driveToBinFull(_ c: MockRobotConnector) throws {
        try complete(c.send(.start(.deep)))
        while try state(c).status == .cleaning { c.tick() }
    }

    func testFullBinStopsWithErrorUntilEmptied() throws {
        let c = try connected(makeConnector())
        try driveToBinFull(c)
        XCTAssertEqual(try state(c).status, .error)
        XCTAssertEqual(try state(c).binPercent, 100)
        XCTAssertNotNil(try state(c).errorMessage)
        XCTAssertThrowsError(try complete(c.send(.start(.quick))))
        try complete(c.send(.emptyBin))
        XCTAssertEqual(try state(c).status, .docked)
        XCTAssertEqual(try state(c).binPercent, 0)
        XCTAssertNil(try state(c).errorMessage)
    }

    func testLowBatteryInterruptsReturnsToDockAndCharges() throws {
        let c = try connected(makeConnector())
        try driveToBinFull(c)
        try complete(c.send(.emptyBin))                 // battery is now 55%, bin 0%
        try complete(c.send(.start(.deep)))
        while try state(c).status == .cleaning { c.tick() }
        XCTAssertEqual(try state(c).status, .returningToDock)
        XCTAssertEqual(try state(c).batteryPercent, MockRobotConnector.lowBatteryThreshold)
        XCTAssertEqual(try latest(c.history).first?.outcome, .interrupted)

        c.tick()
        XCTAssertEqual(try state(c).status, .charging)
        for _ in 0..<30 { c.tick() }
        XCTAssertEqual(try state(c).status, .docked)
        XCTAssertEqual(try state(c).batteryPercent, 100)
    }

    func testStartIsRejectedWhenBatteryTooLow() throws {
        let c = try connected(makeConnector())
        try driveToBinFull(c)
        try complete(c.send(.emptyBin))
        try complete(c.send(.start(.deep)))
        while try state(c).status == .cleaning { c.tick() }
        c.tick()  // charging at 20%
        XCTAssertThrowsError(try complete(c.send(.start(.quick)))) {
            XCTAssertTrue(($0 as? RobotError).map { if case .rejected = $0 { return true } else { return false } } ?? false)
        }
    }

    func testInvalidTransitionsAreRejected() throws {
        let c = try connected(makeConnector())
        XCTAssertThrowsError(try complete(c.send(.pause)))
        XCTAssertThrowsError(try complete(c.send(.resume)))
        try complete(c.send(.start(.standard)))
        XCTAssertThrowsError(try complete(c.send(.start(.quick))), "already busy")
        try complete(c.send(.pause))
        c.tick()
        XCTAssertEqual(try state(c).batteryPercent, 100, "paused robot must not drain")
        try complete(c.send(.resume))
        XCTAssertEqual(try state(c).status, .cleaning)
    }

    func testReturnToDockWhileCleaningInterruptsRun() throws {
        let c = try connected(makeConnector())
        try complete(c.send(.start(.standard)))
        c.tick()
        try complete(c.send(.returnToDock))
        XCTAssertEqual(try state(c).status, .returningToDock)
        XCTAssertEqual(try latest(c.history).first?.outcome, .interrupted)
    }

    func testScheduledRunStartsOnDueMinute() throws {
        let due = nextDate(weekday: 2, hour: 9, minute: 0)
        let c = try connected(makeConnector(now: { due }))
        try complete(c.updateSchedule([ScheduleEntry(weekday: 2, hour: 9, minute: 0, mode: .quick)]))
        XCTAssertEqual(try state(c).status, .docked)
        c.tick()
        XCTAssertEqual(try state(c).status, .cleaning)
        XCTAssertEqual(try state(c).mode, .quick)
    }

    func testDisabledScheduleDoesNotRun() throws {
        let due = nextDate(weekday: 2, hour: 9, minute: 0)
        let c = try connected(makeConnector(now: { due }))
        try complete(c.updateSchedule([ScheduleEntry(weekday: 2, hour: 9, minute: 0, isEnabled: false)]))
        c.tick()
        XCTAssertEqual(try state(c).status, .docked)
    }

    func testScheduleAndSettingsPersistPerDevice() throws {
        let suite = UserDefaults(suiteName: "MockRobotConnectorTests-\(UUID().uuidString)")!
        let first = try connected(makeConnector(defaults: suite, id: "a"))
        let entry = ScheduleEntry(weekday: 4, hour: 18, minute: 30, mode: .deep)
        try complete(first.updateSchedule([entry]))
        var settings = try latest(first.settings)
        settings.suction = .max
        try complete(first.updateSettings(settings))

        let second = makeConnector(defaults: suite, id: "a")
        XCTAssertEqual(try latest(second.schedule), [entry])
        XCTAssertEqual(try latest(second.settings).suction, .max)
        let other = makeConnector(defaults: suite, id: "b")
        XCTAssertNotEqual(try latest(other.schedule), [entry], "devices must not share storage")
    }

    func testClearHistory() throws {
        let c = try connected(makeConnector())
        try complete(c.clearHistory())
        XCTAssertTrue(try latest(c.history).isEmpty)
    }
}
