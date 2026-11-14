import RIBs

protocol LoggedInListener: AnyObject {
    func loggedInDidRequestSignOut()
}

protocol LoggedInBuildable: Buildable {
    func build(withListener listener: LoggedInListener, user: User, host: ContentHosting) -> Routing
}

final class LoggedInBuilder: Builder<LoggedInComponent>, LoggedInBuildable {

    func build(withListener listener: LoggedInListener, user: User, host: ContentHosting) -> Routing {
        let interactor = LoggedInInteractor()
        interactor.listener = listener
        let component = dependency
        return LoggedInRouter(interactor: interactor,
                              host: host,
                              user: user,
                              devicesBuilder: component.devicesBuilder,
                              makeSessionBuilder: { component.sessionBuilder })
    }
}
