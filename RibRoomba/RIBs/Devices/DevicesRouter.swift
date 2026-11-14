import RIBs

protocol DevicesViewControllable: ViewControllable {
    func presentModal(_ viewController: ViewControllable)
    func dismissModal()
}

/// Presents the add-device flow modally; detaches it when the flow finishes.
final class DevicesRouter: ViewableRouter<DevicesInteractable, DevicesViewControllable>, DevicesRouting {

    private let addDeviceBuilder: AddDeviceBuildable
    private var addDeviceRouter: ViewableRouting?

    init(interactor: DevicesInteractable, viewController: DevicesViewControllable, addDeviceBuilder: AddDeviceBuildable) {
        self.addDeviceBuilder = addDeviceBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    func routeToAddDevice() {
        guard addDeviceRouter == nil else { return }
        let router = addDeviceBuilder.build(withListener: interactor)
        addDeviceRouter = router
        attachChild(router)
        viewController.presentModal(router.viewControllable)
    }

    func dismissAddDevice() {
        guard let router = addDeviceRouter else { return }
        viewController.dismissModal()
        detachChild(router)
        addDeviceRouter = nil
    }
}
