import RIBs

protocol LoggedOutBuildable: Buildable {
    func build() -> ViewableRouting
}

final class LoggedOutBuilder: Builder<LoggedOutComponent>, LoggedOutBuildable {

    func build() -> ViewableRouting {
        let viewController = LoggedOutViewController()
        let interactor = LoggedOutInteractor(presenter: viewController, authService: dependency.dependency.authService)
        return LoggedOutRouter(interactor: interactor, viewController: viewController)
    }
}
