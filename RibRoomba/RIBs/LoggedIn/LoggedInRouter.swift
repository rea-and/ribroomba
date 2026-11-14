import RIBs

final class LoggedInRouter: Router<LoggedInInteractable>, LoggedInRouting {

    private let host: ContentHosting
    private let user: User
    private let devicesBuilder: DevicesBuildable
    private let makeSessionBuilder: () -> SessionBuildable
    private var current: Routing?

    init(interactor: LoggedInInteractable,
         host: ContentHosting,
         user: User,
         devicesBuilder: DevicesBuildable,
         makeSessionBuilder: @escaping () -> SessionBuildable) {
        self.host = host
        self.user = user
        self.devicesBuilder = devicesBuilder
        self.makeSessionBuilder = makeSessionBuilder
        super.init(interactor: interactor)
        interactor.router = self
    }

    override func didLoad() {
        super.didLoad()
        routeToDevices()
    }

    func routeToDevices() {
        detachCurrent()
        let router = devicesBuilder.build(withListener: interactor, user: user)
        current = router
        attachChild(router)
        host.setContent(router.viewControllable, embeddedInNavigation: true)
    }

    func routeToSession(device: Device) {
        detachCurrent()
        let router = makeSessionBuilder().build(withListener: interactor, device: device, host: host)
        current = router
        attachChild(router)  // The session installs its tabs into `host` when it loads.
    }

    private func detachCurrent() {
        guard let current = current else { return }
        detachChild(current)
        self.current = nil
    }
}
