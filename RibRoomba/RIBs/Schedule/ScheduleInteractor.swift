import Foundation
import RIBs
import RxSwift

protocol ScheduleRouting: ViewableRouting {
    func routeToEditor(editing entry: ScheduleEntry?)
    func dismissEditor()
}

struct ScheduleRowViewModel: Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let isEnabled: Bool
}

struct ScheduleViewModel: Equatable {
    let rows: [ScheduleRowViewModel]
    var isEmpty: Bool { rows.isEmpty }
}

protocol SchedulePresentable: Presentable {
    var listener: SchedulePresentableListener? { get set }
    func render(_ viewModel: ScheduleViewModel)
}

protocol SchedulePresentableListener: AnyObject {
    func didTapAdd()
    func didSelect(id: UUID)
    func didToggle(id: UUID, isEnabled: Bool)
    func didDelete(id: UUID)
}

protocol ScheduleInteractable: Interactable, ScheduleEditorListener {
    var router: ScheduleRouting? { get set }
    var listener: ScheduleListener? { get set }
}

final class ScheduleInteractor: PresentableInteractor<SchedulePresentable>, ScheduleInteractable, SchedulePresentableListener {

    weak var router: ScheduleRouting?
    weak var listener: ScheduleListener?

    private let stream: RobotStateStreaming
    private var entries: [ScheduleEntry] = []

    init(presenter: SchedulePresentable, stream: RobotStateStreaming) {
        self.stream = stream
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        stream.schedule
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] entries in
                self?.entries = entries
                self?.presenter.render(Self.makeViewModel(entries: entries))
            })
            .disposeOnDeactivate(interactor: self)
    }

    // MARK: - SchedulePresentableListener

    func didTapAdd() { router?.routeToEditor(editing: nil) }

    func didSelect(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        router?.routeToEditor(editing: entry)
    }

    func didToggle(id: UUID, isEnabled: Bool) {
        publish(entries.map { $0.id == id ? with($0) { $0.isEnabled = isEnabled } : $0 })
    }

    func didDelete(id: UUID) {
        publish(entries.filter { $0.id != id })
    }

    // MARK: - ScheduleEditorListener

    func scheduleEditorDidSave(_ entry: ScheduleEntry) {
        router?.dismissEditor()
        if entries.contains(where: { $0.id == entry.id }) {
            publish(entries.map { $0.id == entry.id ? entry : $0 })
        } else {
            publish(entries + [entry])
        }
    }

    func scheduleEditorDidCancel() {
        router?.dismissEditor()
    }

    // MARK: - Private

    private func publish(_ updated: [ScheduleEntry]) {
        listener?.scheduleDidChange(updated)
    }

    private func with(_ entry: ScheduleEntry, _ change: (inout ScheduleEntry) -> Void) -> ScheduleEntry {
        var copy = entry
        change(&copy)
        return copy
    }

    static func makeViewModel(entries: [ScheduleEntry]) -> ScheduleViewModel {
        let symbols = Calendar.current.weekdaySymbols
        let sorted = entries.sorted { ($0.weekday, $0.hour, $0.minute) < ($1.weekday, $1.hour, $1.minute) }
        return ScheduleViewModel(rows: sorted.map {
            ScheduleRowViewModel(id: $0.id,
                                 title: "\(symbols[($0.weekday - 1) % symbols.count]) \(String(format: "%02d:%02d", $0.hour, $0.minute))",
                                 subtitle: "\($0.mode.displayName) clean",
                                 isEnabled: $0.isEnabled)
        })
    }
}
