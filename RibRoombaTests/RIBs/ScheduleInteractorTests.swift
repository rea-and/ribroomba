import XCTest
@testable import RibRoomba

private final class StubPresenter: SchedulePresentable {
    weak var listener: SchedulePresentableListener?
    private(set) var last: ScheduleViewModel?
    func render(_ viewModel: ScheduleViewModel) { last = viewModel }
}

private final class StubRouter: ScheduleRouting {
    // Only the calls made by the interactor are needed; ViewableRouting requirements are unused by it.
    var interactable: Interactable { fatalError() }
    var viewControllable: ViewControllable { fatalError() }
    var children: [Routing] = []
    var lifecycle: Observable<RouterLifecycle> { .empty() }
    func load() {}
    func attachChild(_ child: Routing) {}
    func detachChild(_ child: Routing) {}
    var editorRoutes: [ScheduleEntry?] = []
    var dismissCount = 0
    func routeToEditor(editing entry: ScheduleEntry?) { editorRoutes.append(entry) }
    func dismissEditor() { dismissCount += 1 }
}

private final class ListenerSpy: ScheduleListener {
    var changes: [[ScheduleEntry]] = []
    func scheduleDidChange(_ entries: [ScheduleEntry]) { changes.append(entries) }
}

import RIBs
import RxSwift

final class ScheduleInteractorTests: XCTestCase {

    private let a = ScheduleEntry(weekday: 2, hour: 9, minute: 0)
    private let b = ScheduleEntry(weekday: 4, hour: 18, minute: 0, mode: .deep)
    private var stream: MutableRobotStateStream!
    private var presenter: StubPresenter!
    private var router: StubRouter!
    private var listener: ListenerSpy!
    private var sut: ScheduleInteractor!

    override func setUp() {
        super.setUp()
        stream = MutableRobotStateStream()
        stream.update(schedule: [a, b])
        presenter = StubPresenter()
        router = StubRouter()
        listener = ListenerSpy()
        sut = ScheduleInteractor(presenter: presenter, stream: stream)
        sut.router = router
        sut.listener = listener
        sut.activate()
        drainMainQueue()
    }

    func testRendersStreamedSchedule() {
        XCTAssertEqual(presenter.last?.rows.count, 2)
    }

    func testToggleReportsUpdatedListToParent() {
        sut.didToggle(id: a.id, isEnabled: false)
        XCTAssertEqual(listener.changes.last?.first(where: { $0.id == a.id })?.isEnabled, false)
        XCTAssertEqual(listener.changes.last?.count, 2)
    }

    func testDeleteRemovesEntry() {
        sut.didDelete(id: b.id)
        XCTAssertEqual(listener.changes.last, [a])
    }

    func testSelectRoutesToEditorWithEntry() {
        sut.didSelect(id: b.id)
        XCTAssertEqual(router.editorRoutes.count, 1)
        XCTAssertEqual(router.editorRoutes.first??.id, b.id)
    }

    func testEditorSaveOfNewEntryAppendsAndDismisses() {
        let new = ScheduleEntry(weekday: 6, hour: 8, minute: 15)
        sut.scheduleEditorDidSave(new)
        XCTAssertEqual(router.dismissCount, 1)
        XCTAssertEqual(listener.changes.last, [a, b, new])
    }

    func testEditorSaveOfExistingEntryReplacesIt() {
        var edited = a
        edited.hour = 10
        sut.scheduleEditorDidSave(edited)
        XCTAssertEqual(listener.changes.last, [edited, b])
    }

    func testEditorCancelOnlyDismisses() {
        sut.scheduleEditorDidCancel()
        XCTAssertEqual(router.dismissCount, 1)
        XCTAssertTrue(listener.changes.isEmpty)
    }
}
