import RIBs

protocol HistoryViewControllable: ViewControllable {}

final class HistoryRouter: ViewableRouter<HistoryInteractable, HistoryViewControllable>, HistoryRouting {

    override init(interactor: HistoryInteractable, viewController: HistoryViewControllable) {
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }
}
