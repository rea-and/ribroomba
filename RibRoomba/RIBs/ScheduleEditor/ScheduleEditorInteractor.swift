import Foundation
import RIBs

protocol ScheduleEditorRouting: ViewableRouting {}

struct ScheduleEditorViewModel: Equatable {
    let title: String
    let weekday: Int
    let hour: Int
    let minute: Int
    let mode: CleaningMode
}

protocol ScheduleEditorPresentable: Presentable {
    var listener: ScheduleEditorPresentableListener? { get set }
    func render(_ viewModel: ScheduleEditorViewModel)
}

protocol ScheduleEditorPresentableListener: AnyObject {
    func didTapSave(weekday: Int, hour: Int, minute: Int, mode: CleaningMode)
    func didTapCancel()
}

protocol ScheduleEditorInteractable: Interactable {
    var router: ScheduleEditorRouting? { get set }
    var listener: ScheduleEditorListener? { get set }
}

final class ScheduleEditorInteractor: PresentableInteractor<ScheduleEditorPresentable>, ScheduleEditorInteractable, ScheduleEditorPresentableListener {

    weak var router: ScheduleEditorRouting?
    weak var listener: ScheduleEditorListener?

    private let entry: ScheduleEntry?

    init(presenter: ScheduleEditorPresentable, entry: ScheduleEntry?) {
        self.entry = entry
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        let e = entry
        presenter.render(ScheduleEditorViewModel(title: e == nil ? "New schedule" : "Edit schedule",
                                                 weekday: e?.weekday ?? 2,
                                                 hour: e?.hour ?? 9,
                                                 minute: e?.minute ?? 0,
                                                 mode: e?.mode ?? .standard))
    }

    func didTapSave(weekday: Int, hour: Int, minute: Int, mode: CleaningMode) {
        let saved = ScheduleEntry(id: entry?.id ?? UUID(), weekday: weekday, hour: hour, minute: minute,
                                  mode: mode, isEnabled: entry?.isEnabled ?? true)
        listener?.scheduleEditorDidSave(saved)
    }

    func didTapCancel() {
        listener?.scheduleEditorDidCancel()
    }
}
