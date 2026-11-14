import RIBs

/// Lets viewless RIBs place their children's views in the app's single content area.
protocol ContentHosting: AnyObject {
    func setContent(_ viewController: ViewControllable, embeddedInNavigation: Bool)
    func setTabs(_ viewControllers: [ViewControllable])
}

extension ContentHosting {
    func setContent(_ viewController: ViewControllable) { setContent(viewController, embeddedInNavigation: false) }
}

protocol RootViewControllable: ViewControllable, ContentHosting {}

/// Launch router. Swaps between the logged-out and logged-in subtrees.
final class RootRouter: LaunchRouter<RootInteractable, RootViewControllable>, RootRouting {

    private let loggedOutBuilder: LoggedOutBuildable
    private let loggedInBuilder: LoggedInBuildable
    private var current: Routing?

    init(interactor: RootInteractable,
         viewController: RootViewControllable,
         loggedOutBuilder: LoggedOutBuildable,
         loggedInBuilder: LoggedInBuildable) {
        self.loggedOutBuilder = loggedOutBuilder
        self.loggedInBuilder = loggedInBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    func routeToLoggedOut() {
        detachCurrent()
        let router = loggedOutBuilder.build()
        current = router
        attachChild(router)
        viewController.setContent(router.viewControllable)
    }

    func routeToLoggedIn(user: User) {
        detachCurrent()
        let router = loggedInBuilder.build(withListener: interactor, user: user, host: viewController)
        current = router
        attachChild(router)  // LoggedIn is viewless; it places its own views in `host`.
    }

    private func detachCurrent() {
        guard let current = current else { return }
        detachChild(current)
        self.current = nil
    }
}
