import RIBs

protocol AddDeviceListener: AnyObject {
    func addDeviceDidAdd(_ device: Device)
    func addDeviceDidCancel()
}

protocol AddDeviceBuildable: Buildable {
    func build(withListener listener: AddDeviceListener) -> ViewableRouting
}

final class AddDeviceBuilder: Builder<AddDeviceComponent>, AddDeviceBuildable {

    func build(withListener listener: AddDeviceListener) -> ViewableRouting {
        let viewController = AddDeviceViewController()
        let interactor = AddDeviceInteractor(presenter: viewController, deviceManager: dependency.dependency.deviceManager)
        interactor.listener = listener
        return AddDeviceRouter(interactor: interactor, viewController: viewController)
    }
}
