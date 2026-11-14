import RIBs

protocol ScheduleListener: AnyObject {
    func scheduleDidChange(_ entries: [ScheduleEntry])
}

protocol ScheduleBuildable: Buildable {
    func build(withListener listener: ScheduleListener) -> ViewableRouting
}

final class ScheduleBuilder: Builder<ScheduleComponent>, ScheduleBuildable {

    func build(withListener listener: ScheduleListener) -> ViewableRouting {
        let viewController = ScheduleViewController()
        let interactor = ScheduleInteractor(presenter: viewController, stream: dependency.dependency.robotStateStream)
        interactor.listener = listener
        return ScheduleRouter(interactor: interactor,
                              viewController: viewController,
                              editorBuilder: dependency.scheduleEditorBuilder)
    }
}
