import NeedleFoundation

protocol LoggedInDependency: Dependency {
    var deviceManager: DeviceManaging { get }
}

/// Scope of an authenticated user: chooses a device (Devices), then runs a RobotSession for it.
final class LoggedInComponent: Component<LoggedInDependency> {

    var devicesBuilder: DevicesBuildable {
        return DevicesBuilder(dependency: DevicesComponent(parent: self))
    }

    /// Computed on purpose: every access creates a fresh `SessionComponent`, so each session gets its own state stream.
    var sessionBuilder: SessionBuildable {
        return SessionBuilder(dependency: SessionComponent(parent: self))
    }
}
