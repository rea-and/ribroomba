import RIBs

protocol LoggedInRouting: Routing {
    func routeToDevices()
    func routeToSession(device: Device)
}

protocol LoggedInInteractable: Interactable, DevicesListener, SessionListener {
    var router: LoggedInRouting? { get set }
    var listener: LoggedInListener? { get set }
}

/// Viewless coordinator: Devices list <-> Session for the chosen device.
final class LoggedInInteractor: Interactor, LoggedInInteractable {

    weak var router: LoggedInRouting?
    weak var listener: LoggedInListener?

    // MARK: - DevicesListener

    func devicesDidSelect(_ device: Device) { router?.routeToSession(device: device) }
    func devicesDidRequestSignOut() { listener?.loggedInDidRequestSignOut() }

    // MARK: - SessionListener

    func sessionDidRequestSwitchDevice() { router?.routeToDevices() }
    func sessionDidRequestSignOut() { listener?.loggedInDidRequestSignOut() }
}
