import Foundation
import RxSwift
import XCTest
@testable import RibRoomba

/// Interactors hop to the main scheduler before presenting; let the run loop drain.
func drainMainQueue(_ seconds: TimeInterval = 0.05) {
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
}

final class StubAuthService: AuthServicing {
    var signInResult: Single<User> = .error(AuthError.invalidCredentials)
    var signUpResult: Single<User> = .error(AuthError.invalidCredentials)
    private(set) var signInCalls: [(String, String)] = []
    private(set) var signUpCalls: [(String, String, String)] = []

    var currentUser: Observable<User?> { .just(nil) }
    func signIn(email: String, password: String) -> Single<User> { signInCalls.append((email, password)); return signInResult }
    func signUp(name: String, email: String, password: String) -> Single<User> {
        signUpCalls.append((name, email, password)); return signUpResult
    }
    func signOut() -> Completable { .empty() }
}
