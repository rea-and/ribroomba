import RIBs

protocol ScheduleEditorViewControllable: ViewControllable {}

final class ScheduleEditorRouter: ViewableRouter<ScheduleEditorInteractable, ScheduleEditorViewControllable>, ScheduleEditorRouting {

    override init(interactor: ScheduleEditorInteractable, viewController: ScheduleEditorViewControllable) {
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }
}
