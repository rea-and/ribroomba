import RIBs
import RxSwift

protocol SessionRouting: Routing {}

protocol SessionInteractable: Interactable, HomeListener, ScheduleListener, HistoryListener, SettingsListener {
    var router: SessionRouting? { get set }
    var listener: SessionListener? { get set }
}

/// Viewless business-logic owner. Talks to the device through `RobotConnecting`, publishes the result into the
/// session stream, and executes requests children make through their listener protocols.
final class SessionInteractor: Interactor, SessionInteractable {

    weak var router: SessionRouting?
    weak var listener: SessionListener?

    private let connector: RobotConnecting
    private let stream: MutableRobotStateStream

    init(connector: RobotConnecting, stream: MutableRobotStateStream) {
        self.connector = connector
        self.stream = stream
        super.init()
    }

    override func didBecomeActive() {
        super.didBecomeActive()

        connector.connection.subscribe(onNext: { [stream] in stream.update(connection: $0) })
            .disposeOnDeactivate(interactor: self)
        connector.state.subscribe(onNext: { [stream] in stream.update(state: $0) })
            .disposeOnDeactivate(interactor: self)
        connector.history.subscribe(onNext: { [stream] in stream.update(history: $0) })
            .disposeOnDeactivate(interactor: self)
        connector.schedule.subscribe(onNext: { [stream] in stream.update(schedule: $0) })
            .disposeOnDeactivate(interactor: self)
        connector.settings.subscribe(onNext: { [stream] in stream.update(settings: $0) })
            .disposeOnDeactivate(interactor: self)

        connect()
    }

    // MARK: - HomeListener

    func homeDidRequest(_ command: RobotCommand) {
        run(connector.send(command))
    }

    func homeDidRequestReconnect() {
        connect()
    }

    // MARK: - ScheduleListener

    func scheduleDidChange(_ entries: [ScheduleEntry]) {
        run(connector.updateSchedule(entries))
    }

    // MARK: - HistoryListener

    func historyDidRequestClear() {
        run(connector.clearHistory())
    }

    // MARK: - SettingsListener

    func settingsDidChange(_ settings: RobotSettings) {
        run(connector.updateSettings(settings))
    }

    func settingsDidRequestSwitchDevice() { listener?.sessionDidRequestSwitchDevice() }

    func settingsDidRequestSignOut() { listener?.sessionDidRequestSignOut() }

    // MARK: - Private

    private func connect() {
        run(connector.connect(), onError: { [stream] in stream.update(connection: .disconnected) })
    }

    private func run(_ completable: Completable, onError: (() -> Void)? = nil) {
        completable
            .observe(on: MainScheduler.instance)
            .subscribe(onError: { [stream] error in
                onError?()
                stream.report(error: error.localizedDescription)
            })
            .disposeOnDeactivate(interactor: self)
    }
}
