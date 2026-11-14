import Foundation
import RxRelay
import RxSwift

// MARK: - Contract

public struct User: Codable, Equatable {
    public let id: String
    public let name: String
    public let email: String
}

public enum AuthError: Error, LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case invalidCredentials
    case emailAlreadyRegistered
    case missingName

    public var errorDescription: String? {
        switch self {
        case .invalidEmail: return "Enter a valid email address."
        case .weakPassword: return "Password must be at least 6 characters."
        case .invalidCredentials: return "Incorrect email or password."
        case .emailAlreadyRegistered: return "An account with this email already exists."
        case .missingName: return "Enter your name."
        }
    }
}

/// Account backend abstraction. `MockAuthService` is used today; a real implementation (REST, Firebase, …) plugs
/// in at `RootComponent` without any RIB changing.
public protocol AuthServicing: AnyObject {
    /// The signed-in user, `nil` when signed out. Replays the latest value (including a restored session).
    var currentUser: Observable<User?> { get }
    func signIn(email: String, password: String) -> Single<User>
    func signUp(name: String, email: String, password: String) -> Single<User>
    func signOut() -> Completable
}

// MARK: - Mock

/// In-memory/`UserDefaults` account store with simulated latency. Seeded with a demo account:
/// `demo@ribroomba.app` / `roomba123`. Passwords are stored in plain text — acceptable ONLY because this is a mock.
final class MockAuthService: AuthServicing {

    private struct Account: Codable { var user: User; var password: String }

    private let defaults: UserDefaults?
    private let latency: RxTimeInterval
    private let scheduler: SchedulerType
    private let userRelay = BehaviorRelay<User?>(value: nil)
    private var accounts: [String: Account]

    private static let accountsKey = "mock.auth.accounts"
    private static let sessionKey = "mock.auth.sessionEmail"

    var currentUser: Observable<User?> { userRelay.asObservable() }

    init(defaults: UserDefaults? = .standard,
         latency: RxTimeInterval = .milliseconds(700),
         scheduler: SchedulerType = MainScheduler.instance) {
        self.defaults = defaults
        self.latency = latency
        self.scheduler = scheduler

        let demo = Account(user: User(id: "demo", name: "Demo User", email: "demo@ribroomba.app"), password: "roomba123")
        var stored: [String: Account] = [:]
        if let data = defaults?.data(forKey: Self.accountsKey),
           let decoded = try? JSONDecoder().decode([String: Account].self, from: data) {
            stored = decoded
        }
        stored[demo.user.email] = stored[demo.user.email] ?? demo
        accounts = stored

        if let email = defaults?.string(forKey: Self.sessionKey), let account = accounts[email] {
            userRelay.accept(account.user)  // restored session
        }
    }

    func signIn(email: String, password: String) -> Single<User> {
        respond { [self] in
            let key = Self.normalize(email)
            guard Self.isValid(email: key) else { throw AuthError.invalidEmail }
            guard let account = accounts[key], account.password == password else { throw AuthError.invalidCredentials }
            startSession(account.user)
            return account.user
        }
    }

    func signUp(name: String, email: String, password: String) -> Single<User> {
        respond { [self] in
            let key = Self.normalize(email)
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { throw AuthError.missingName }
            guard Self.isValid(email: key) else { throw AuthError.invalidEmail }
            guard password.count >= 6 else { throw AuthError.weakPassword }
            guard accounts[key] == nil else { throw AuthError.emailAlreadyRegistered }
            let user = User(id: UUID().uuidString, name: trimmedName, email: key)
            accounts[key] = Account(user: user, password: password)
            if let data = try? JSONEncoder().encode(accounts) { defaults?.set(data, forKey: Self.accountsKey) }
            startSession(user)
            return user
        }
    }

    func signOut() -> Completable {
        Completable.create { [weak self] completable in
            self?.defaults?.removeObject(forKey: Self.sessionKey)
            self?.userRelay.accept(nil)
            completable(.completed)
            return Disposables.create()
        }
    }

    // MARK: - Private

    private func startSession(_ user: User) {
        defaults?.set(user.email, forKey: Self.sessionKey)
        userRelay.accept(user)
    }

    private func respond<T>(_ work: @escaping () throws -> T) -> Single<T> {
        Single<Int>.timer(latency, scheduler: scheduler).map { _ in try work() }
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isValid(email: String) -> Bool {
        email.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }
}
