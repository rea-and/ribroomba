import RIBs
import RxSwift

protocol RootRouting: LaunchRouting {
    func routeToLoggedOut()
    func routeToLoggedIn(user: User)
}

protocol RootPresentable: Presentable {}

protocol RootInteractable: Interactable, LoggedInListener {
    var router: RootRouting? { get set }
}

/// Source of truth for "who is signed in". Reacts to `AuthServicing.currentUser`, so a restored session, a fresh
/// login and a sign-out all take the same path.
final class RootInteractor: PresentableInteractor<RootPresentable>, RootInteractable {

    weak var router: RootRouting?

    private let authService: AuthServicing

    init(presenter: RootPresentable, authService: AuthServicing) {
        self.authService = authService
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        authService.currentUser
            .distinctUntilChanged { $0?.id == $1?.id }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] user in
                if let user = user { self?.router?.routeToLoggedIn(user: user) } else { self?.router?.routeToLoggedOut() }
            })
            .disposeOnDeactivate(interactor: self)
    }

    // MARK: - LoggedInListener

    func loggedInDidRequestSignOut() {
        authService.signOut()
            .subscribe()
            .disposeOnDeactivate(interactor: self)
    }
}
