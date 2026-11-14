import RIBs

protocol RootBuildable: Buildable {
    func build() -> LaunchRouting
}

final class RootBuilder: Builder<RootComponent>, RootBuildable {

    func build() -> LaunchRouting {
        let viewController = RootViewController()
        let interactor = RootInteractor(presenter: viewController, authService: dependency.authService)
        return RootRouter(interactor: interactor,
                          viewController: viewController,
                          loggedOutBuilder: dependency.loggedOutBuilder,
                          loggedInBuilder: dependency.loggedInBuilder)
    }
}
