import NeedleFoundation

/// Root of the Needle graph. This is the ONLY place the low-level services are chosen: swap the mocks for real
/// `AuthServicing` / `DeviceManaging` implementations here and no RIB changes.
///
/// - Note: Needle 0.25 only registers provider properties declared `public`.
final class RootComponent: BootstrapComponent {

    public var authService: AuthServicing {
        return shared { MockAuthService() }
    }

    public var deviceManager: DeviceManaging {
        return shared { MockDeviceManager() }
    }

    var rootBuilder: RootBuildable {
        return RootBuilder(dependency: self)
    }

    var loggedOutBuilder: LoggedOutBuildable {
        return LoggedOutBuilder(dependency: LoggedOutComponent(parent: self))
    }

    var loggedInBuilder: LoggedInBuildable {
        return LoggedInBuilder(dependency: LoggedInComponent(parent: self))
    }
}
