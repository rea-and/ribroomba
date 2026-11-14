import XCTest
@testable import RibRoomba

final class FeatureViewModelTests: XCTestCase {

    // MARK: Home

    func testHomeDockedOffersStart() {
        let vm = HomeInteractor.makeViewModel(state: .initial, connection: .connected)
        XCTAssertEqual(vm.statusTitle, "Docked")
        XCTAssertEqual(vm.primaryAction, .start)
        XCTAssertFalse(vm.canDock)
        XCTAssertTrue(vm.canEmptyBin)
    }

    func testHomeCleaningOffersPauseAndDock() {
        var s = RobotState.initial
        s.status = .cleaning
        let vm = HomeInteractor.makeViewModel(state: s, connection: .connected)
        XCTAssertEqual(vm.primaryAction, .pause)
        XCTAssertTrue(vm.canDock)
        XCTAssertFalse(vm.canEmptyBin, "cannot empty the bin mid-run")
    }

    func testHomeOfflineDisablesEverythingAndOffersReconnect() {
        let vm = HomeInteractor.makeViewModel(state: .initial, connection: .disconnected)
        XCTAssertEqual(vm.statusTitle, "Offline")
        XCTAssertEqual(vm.primaryAction, .none)
        XCTAssertFalse(vm.canDock)
        XCTAssertTrue(vm.canReconnect)
    }

    func testHomeErrorShowsMessage() {
        var s = RobotState.initial
        s.status = .error
        s.errorMessage = "Bin is full"
        let vm = HomeInteractor.makeViewModel(state: s, connection: .connected)
        XCTAssertEqual(vm.statusDetail, "Bin is full")
        XCTAssertEqual(vm.primaryAction, .none)
        XCTAssertTrue(vm.canDock)
    }

    // MARK: History

    func testHistoryEmptyState() {
        let vm = HistoryInteractor.makeViewModel(records: [])
        XCTAssertTrue(vm.isEmpty)
        XCTAssertEqual(vm.summary, "No cleaning runs yet")
    }

    func testHistorySummaryTotals() {
        let records = [
            CleaningRecord(id: UUID(), startDate: Date(), duration: 600, area: 10, mode: .quick, outcome: .completed),
            CleaningRecord(id: UUID(), startDate: Date(), duration: 1200, area: 5.5, mode: .deep, outcome: .interrupted),
        ]
        let vm = HistoryInteractor.makeViewModel(records: records)
        XCTAssertEqual(vm.summary, "2 runs · 15.5 m² total")
        XCTAssertEqual(vm.rows.map(\.outcomeText), ["Completed", "Interrupted"])
        XCTAssertEqual(vm.rows.first?.subtitle, "Quick · 10 min · 10.0 m²")
    }

    // MARK: Schedule

    func testScheduleRowsAreSortedByDayAndTime() {
        let late = ScheduleEntry(weekday: 2, hour: 18, minute: 0)
        let early = ScheduleEntry(weekday: 2, hour: 7, minute: 30, mode: .quick)
        let sunday = ScheduleEntry(weekday: 1, hour: 12, minute: 0)
        let vm = ScheduleInteractor.makeViewModel(entries: [late, early, sunday])
        XCTAssertEqual(vm.rows.map(\.id), [sunday.id, early.id, late.id])
        XCTAssertTrue(vm.rows[1].title.hasSuffix("07:30"))
    }
}
