import NeedleFoundation

protocol HomeDependency: Dependency {
    var robotStateStream: RobotStateStreaming { get }
}

final class HomeComponent: Component<HomeDependency> {}
