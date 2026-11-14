import NeedleFoundation

protocol SettingsDependency: Dependency {
    var robotStateStream: RobotStateStreaming { get }
}

final class SettingsComponent: Component<SettingsDependency> {}
