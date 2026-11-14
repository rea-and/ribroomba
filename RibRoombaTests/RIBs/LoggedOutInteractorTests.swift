import RxSwift
import XCTest
@testable import RibRoomba

private final class StubPresenter: LoggedOutPresentable {
    weak var listener: LoggedOutPresentableListener?
    private(set) var rendered: [LoggedOutViewModel] = []
    func render(_ viewModel: LoggedOutViewModel) { rendered.append(viewModel) }
}

final class LoggedOutInteractorTests: XCTestCase {

    private var auth: StubAuthService!
    private var presenter: StubPresenter!
    private var sut: LoggedOutInteractor!

    override func setUp() {
        super.setUp()
        auth = StubAuthService()
        presenter = StubPresenter()
        sut = LoggedOutInteractor(presenter: presenter, authService: auth)
        sut.activate()
    }

    func testStartsInLoginModeWithoutError() {
        XCTAssertEqual(presenter.rendered.last, LoggedOutViewModel(mode: .login, isLoading: false, errorMessage: nil))
        XCTAssertFalse(presenter.rendered.last!.showsNameField)
    }

    func testSwitchingToSignUpShowsNameField() {
        sut.didSelect(mode: .signUp)
        XCTAssertTrue(presenter.rendered.last!.showsNameField)
        XCTAssertEqual(presenter.rendered.last!.submitTitle, "Create account")
    }

    func testFailedLoginShowsErrorAndStopsLoading() {
        sut.didTapSubmit(name: "", email: "a@b.co", password: "bad")
        drainMainQueue()
        XCTAssertEqual(auth.signInCalls.count, 1)
        XCTAssertEqual(presenter.rendered.last?.errorMessage, AuthError.invalidCredentials.localizedDescription)
        XCTAssertEqual(presenter.rendered.last?.isLoading, false)
    }

    func testSignUpModeCallsSignUp() {
        sut.didSelect(mode: .signUp)
        sut.didTapSubmit(name: "Ann", email: "a@b.co", password: "secret1")
        XCTAssertEqual(auth.signUpCalls.count, 1)
        XCTAssertEqual(auth.signInCalls.count, 0)
    }

    func testSubmitWhileLoadingIsIgnored() {
        auth.signInResult = .never()
        sut.didTapSubmit(name: "", email: "a@b.co", password: "x")
        sut.didTapSubmit(name: "", email: "a@b.co", password: "x")
        XCTAssertEqual(auth.signInCalls.count, 1)
        XCTAssertTrue(presenter.rendered.last!.isLoading)
    }
}
