import NeedleFoundation

protocol LoggedOutDependency: Dependency {
    var authService: AuthServicing { get }
}

final class LoggedOutComponent: Component<LoggedOutDependency> {}
