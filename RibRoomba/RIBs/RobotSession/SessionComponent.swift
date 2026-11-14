import NeedleFoundation

protocol SessionDependency: Dependency {
    /// Hands the session the connector for the device it was started for.
    var deviceManager: DeviceManaging { get }
}

/// Scope that owns the robot's live state. Children see only the read-only `robotStateStream`; the connector and
/// the mutable stream are never exposed to them.
final class SessionComponent: Component<SessionDependency> {

    var mutableRobotStateStream: MutableRobotStateStream {
        return shared { MutableRobotStateStream() }
    }

    /// Read-only projection given to children. (`public`: required for Needle to register it as a provider.)
    public var robotStateStream: RobotStateStreaming {
        return mutableRobotStateStream
    }

    var homeBuilder: HomeBuildable { return HomeBuilder(dependency: HomeComponent(parent: self)) }
    var scheduleBuilder: ScheduleBuildable { return ScheduleBuilder(dependency: ScheduleComponent(parent: self)) }
    var historyBuilder: HistoryBuildable { return HistoryBuilder(dependency: HistoryComponent(parent: self)) }
    var settingsBuilder: SettingsBuildable { return SettingsBuilder(dependency: SettingsComponent(parent: self)) }
}
