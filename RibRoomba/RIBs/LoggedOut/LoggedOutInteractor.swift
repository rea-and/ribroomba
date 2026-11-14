import RIBs
import RxSwift

protocol LoggedOutRouting: ViewableRouting {}

enum AuthMode: Equatable { case login, signUp }

struct LoggedOutViewModel: Equatable {
    var mode: AuthMode
    var isLoading: Bool
    var errorMessage: String?

    var showsNameField: Bool { mode == .signUp }
    var submitTitle: String { mode == .login ? "Log in" : "Create account" }
}

protocol LoggedOutPresentable: Presentable {
    var listener: LoggedOutPresentableListener? { get set }
    func render(_ viewModel: LoggedOutViewModel)
}

protocol LoggedOutPresentableListener: AnyObject {
    func didSelect(mode: AuthMode)
    func didTapSubmit(name: String, email: String, password: String)
}

protocol LoggedOutInteractable: Interactable {
    var router: LoggedOutRouting? { get set }
}

/// Drives login and sign-up. On success the auth service publishes the new user and Root swaps subtrees; this RIB
/// never navigates by itself.
final class LoggedOutInteractor: PresentableInteractor<LoggedOutPresentable>, LoggedOutInteractable, LoggedOutPresentableListener {

    weak var router: LoggedOutRouting?

    private let authService: AuthServicing
    private var viewModel = LoggedOutViewModel(mode: .login, isLoading: false, errorMessage: nil) {
        didSet { presenter.render(viewModel) }
    }

    init(presenter: LoggedOutPresentable, authService: AuthServicing) {
        self.authService = authService
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        presenter.render(viewModel)
    }

    func didSelect(mode: AuthMode) {
        guard !viewModel.isLoading else { return }
        viewModel = LoggedOutViewModel(mode: mode, isLoading: false, errorMessage: nil)
    }

    func didTapSubmit(name: String, email: String, password: String) {
        guard !viewModel.isLoading else { return }
        viewModel.isLoading = true
        viewModel.errorMessage = nil

        let request: Single<User> = viewModel.mode == .login
            ? authService.signIn(email: email, password: password)
            : authService.signUp(name: name, email: email, password: password)

        request
            .observe(on: MainScheduler.instance)
            .subscribe(onFailure: { [weak self] error in
                self?.viewModel.isLoading = false
                self?.viewModel.errorMessage = error.localizedDescription
            })
            .disposeOnDeactivate(interactor: self)
    }
}
