import XCTest
import RxBlocking
import RxSwift
@testable import RibRoomba

final class MockAuthServiceTests: XCTestCase {

    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = UserDefaults(suiteName: "MockAuthServiceTests-\(UUID().uuidString)")
    }

    private func makeService() -> MockAuthService {
        MockAuthService(defaults: suite, latency: .milliseconds(1), scheduler: testScheduler)
    }

    private func currentUser(_ s: MockAuthService) throws -> User? { try latest(s.currentUser) }

    func testDemoAccountSignsIn() throws {
        let s = makeService()
        XCTAssertNil(try currentUser(s))
        let user = try s.signIn(email: " Demo@RibRoomba.app ", password: "roomba123").toBlocking(timeout: 5).first()
        XCTAssertEqual(user?.name, "Demo User")
        XCTAssertEqual(try currentUser(s), user)
    }

    func testWrongPasswordFails() {
        XCTAssertThrowsError(try makeService().signIn(email: "demo@ribroomba.app", password: "nope").toBlocking(timeout: 5).first()) {
            XCTAssertEqual($0 as? AuthError, .invalidCredentials)
        }
    }

    func testSignUpValidation() {
        let s = makeService()
        func failure(name: String = "Ann", email: String = "ann@x.io", password: String = "secret1") -> AuthError? {
            do { _ = try s.signUp(name: name, email: email, password: password).toBlocking(timeout: 5).first(); return nil }
            catch { return error as? AuthError }
        }
        XCTAssertEqual(failure(name: "  "), .missingName)
        XCTAssertEqual(failure(email: "not-an-email"), .invalidEmail)
        XCTAssertEqual(failure(password: "123"), .weakPassword)
        XCTAssertEqual(failure(email: "demo@ribroomba.app"), .emailAlreadyRegistered)
    }

    func testSignUpThenSignOutThenSignIn() throws {
        let s = makeService()
        let user = try s.signUp(name: "Ann", email: "ann@x.io", password: "secret1").toBlocking(timeout: 5).first()
        XCTAssertEqual(try currentUser(s), user)
        try complete(s.signOut())
        XCTAssertNil(try currentUser(s))
        XCTAssertEqual(try s.signIn(email: "ann@x.io", password: "secret1").toBlocking(timeout: 5).first(), user)
    }

    func testSessionIsRestoredAcrossLaunches() throws {
        let first = makeService()
        _ = try first.signIn(email: "demo@ribroomba.app", password: "roomba123").toBlocking(timeout: 5).first()
        XCTAssertEqual(try currentUser(makeService())?.email, "demo@ribroomba.app")
        try complete(first.signOut())
        XCTAssertNil(try currentUser(makeService()))
    }

    func testSignedUpAccountPersists() throws {
        _ = try makeService().signUp(name: "Ann", email: "ann@x.io", password: "secret1").toBlocking(timeout: 5).first()
        XCTAssertNoThrow(try makeService().signIn(email: "ann@x.io", password: "secret1").toBlocking(timeout: 5).first())
    }
}
