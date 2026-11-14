import RIBs

protocol DevicesListener: AnyObject {
    func devicesDidSelect(_ device: Device)
    func devicesDidRequestSignOut()
}

protocol DevicesBuildable: Buildable {
    func build(withListener listener: DevicesListener, user: User) -> ViewableRouting
}

final class DevicesBuilder: Builder<DevicesComponent>, DevicesBuildable {

    func build(withListener listener: DevicesListener, user: User) -> ViewableRouting {
        let viewController = DevicesViewController()
        let interactor = DevicesInteractor(presenter: viewController, user: user, deviceManager: dependency.dependency.deviceManager)
        interactor.listener = listener
        return DevicesRouter(interactor: interactor, viewController: viewController, addDeviceBuilder: dependency.addDeviceBuilder)
    }
}
