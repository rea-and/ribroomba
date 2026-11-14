import NeedleFoundation

protocol HistoryDependency: Dependency {
    var robotStateStream: RobotStateStreaming { get }
}

final class HistoryComponent: Component<HistoryDependency> {}
