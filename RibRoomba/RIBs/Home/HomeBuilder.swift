import RIBs

protocol HomeListener: AnyObject {
    func homeDidRequest(_ command: RobotCommand)
    func homeDidRequestReconnect()
}

protocol HomeBuildable: Buildable {
    func build(withListener listener: HomeListener) -> ViewableRouting
}

final class HomeBuilder: Builder<HomeComponent>, HomeBuildable {

    func build(withListener listener: HomeListener) -> ViewableRouting {
        let viewController = HomeViewController()
        let interactor = HomeInteractor(presenter: viewController, stream: dependency.dependency.robotStateStream)
        interactor.listener = listener
        return HomeRouter(interactor: interactor, viewController: viewController)
    }
}
