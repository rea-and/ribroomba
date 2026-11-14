import NeedleFoundation

protocol ScheduleDependency: Dependency {
    var robotStateStream: RobotStateStreaming { get }
}

final class ScheduleComponent: Component<ScheduleDependency> {

    var scheduleEditorBuilder: ScheduleEditorBuildable {
        ScheduleEditorBuilder(dependency: ScheduleEditorComponent(parent: self))
    }
}
