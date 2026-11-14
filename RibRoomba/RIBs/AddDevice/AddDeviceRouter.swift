import RIBs

protocol AddDeviceViewControllable: ViewControllable {}

final class AddDeviceRouter: ViewableRouter<AddDeviceInteractable, AddDeviceViewControllable>, AddDeviceRouting {

    override init(interactor: AddDeviceInteractable, viewController: AddDeviceViewControllable) {
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }
}
