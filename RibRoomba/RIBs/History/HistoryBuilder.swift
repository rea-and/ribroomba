import RIBs

protocol HistoryListener: AnyObject {
    func historyDidRequestClear()
}

protocol HistoryBuildable: Buildable {
    func build(withListener listener: HistoryListener) -> ViewableRouting
}

final class HistoryBuilder: Builder<HistoryComponent>, HistoryBuildable {

    func build(withListener listener: HistoryListener) -> ViewableRouting {
        let viewController = HistoryViewController()
        let interactor = HistoryInteractor(presenter: viewController, stream: dependency.dependency.robotStateStream)
        interactor.listener = listener
        return HistoryRouter(interactor: interactor, viewController: viewController)
    }
}
