import RIBs

protocol ScheduleViewControllable: ViewControllable {
    func presentModal(_ viewController: ViewControllable)
    func dismissModal()
}

/// Presents the editor RIB modally and detaches it again when it finishes.
final class ScheduleRouter: ViewableRouter<ScheduleInteractable, ScheduleViewControllable>, ScheduleRouting {

    private let editorBuilder: ScheduleEditorBuildable
    private var editorRouter: ViewableRouting?

    init(interactor: ScheduleInteractable, viewController: ScheduleViewControllable, editorBuilder: ScheduleEditorBuildable) {
        self.editorBuilder = editorBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    func routeToEditor(editing entry: ScheduleEntry?) {
        guard editorRouter == nil else { return }
        let router = editorBuilder.build(withListener: interactor, entry: entry)
        editorRouter = router
        attachChild(router)
        viewController.presentModal(router.viewControllable)
    }

    func dismissEditor() {
        guard let router = editorRouter else { return }
        viewController.dismissModal()
        detachChild(router)
        editorRouter = nil
    }
}
