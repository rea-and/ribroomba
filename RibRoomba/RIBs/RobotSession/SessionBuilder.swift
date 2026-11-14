import RIBs

protocol SessionListener: AnyObject {
    func sessionDidRequestSwitchDevice()
    func sessionDidRequestSignOut()
}

protocol SessionBuildable: Buildable {
    func build(withListener listener: SessionListener, device: Device, host: ContentHosting) -> SessionRouting
}

final class SessionBuilder: Builder<SessionComponent>, SessionBuildable {

    func build(withListener listener: SessionListener, device: Device, host: ContentHosting) -> SessionRouting {
        let interactor = SessionInteractor(connector: dependency.dependency.deviceManager.connector(for: device),
                                           stream: dependency.mutableRobotStateStream)
        interactor.listener = listener
        return SessionRouter(interactor: interactor,
                             host: host,
                             homeBuilder: dependency.homeBuilder,
                             scheduleBuilder: dependency.scheduleBuilder,
                             historyBuilder: dependency.historyBuilder,
                             settingsBuilder: dependency.settingsBuilder)
    }
}
