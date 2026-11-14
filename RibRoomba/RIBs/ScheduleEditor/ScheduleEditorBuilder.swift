import RIBs

protocol ScheduleEditorListener: AnyObject {
    func scheduleEditorDidSave(_ entry: ScheduleEntry)
    func scheduleEditorDidCancel()
}

protocol ScheduleEditorBuildable: Buildable {
    /// - Parameter entry: The entry to edit, or `nil` to create a new one.
    func build(withListener listener: ScheduleEditorListener, entry: ScheduleEntry?) -> ViewableRouting
}

final class ScheduleEditorBuilder: Builder<ScheduleEditorComponent>, ScheduleEditorBuildable {

    func build(withListener listener: ScheduleEditorListener, entry: ScheduleEntry?) -> ViewableRouting {
        let viewController = ScheduleEditorViewController()
        let interactor = ScheduleEditorInteractor(presenter: viewController, entry: entry)
        interactor.listener = listener
        return ScheduleEditorRouter(interactor: interactor, viewController: viewController)
    }
}
