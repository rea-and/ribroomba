import Foundation
import RIBs
import RxSwift

protocol HistoryRouting: ViewableRouting {}

struct HistoryRowViewModel: Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let outcomeText: String
    let isCompleted: Bool
}

struct HistoryViewModel: Equatable {
    let summary: String
    let rows: [HistoryRowViewModel]
    var isEmpty: Bool { rows.isEmpty }
}

protocol HistoryPresentable: Presentable {
    var listener: HistoryPresentableListener? { get set }
    func render(_ viewModel: HistoryViewModel)
}

protocol HistoryPresentableListener: AnyObject {
    func didTapClear()
}

protocol HistoryInteractable: Interactable {
    var router: HistoryRouting? { get set }
    var listener: HistoryListener? { get set }
}

final class HistoryInteractor: PresentableInteractor<HistoryPresentable>, HistoryInteractable, HistoryPresentableListener {

    weak var router: HistoryRouting?
    weak var listener: HistoryListener?

    private let stream: RobotStateStreaming

    init(presenter: HistoryPresentable, stream: RobotStateStreaming) {
        self.stream = stream
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        stream.history
            .map(Self.makeViewModel)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.presenter.render($0) })
            .disposeOnDeactivate(interactor: self)
    }

    func didTapClear() { listener?.historyDidRequestClear() }

    static func makeViewModel(records: [CleaningRecord]) -> HistoryViewModel {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE d MMM, HH:mm"
        let rows = records.map { r in
            HistoryRowViewModel(
                id: r.id,
                title: dateFormatter.string(from: r.startDate),
                subtitle: "\(r.mode.displayName) · \(Int(r.duration / 60)) min · \(String(format: "%.1f", r.area)) m²",
                outcomeText: r.outcome == .completed ? "Completed" : "Interrupted",
                isCompleted: r.outcome == .completed)
        }
        let totalArea = records.reduce(0) { $0 + $1.area }
        let summary = records.isEmpty ? "No cleaning runs yet"
            : "\(records.count) run\(records.count == 1 ? "" : "s") · \(String(format: "%.1f", totalArea)) m² total"
        return HistoryViewModel(summary: summary, rows: rows)
    }
}
