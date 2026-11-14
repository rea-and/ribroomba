import RIBs
import RxSwift

protocol HomeRouting: ViewableRouting {}

struct HomeViewModel: Equatable {
    enum PrimaryAction: Equatable { case start, pause, resume, none }

    var statusTitle: String
    var statusDetail: String
    var batteryText: String
    var batteryProgress: Float
    var binText: String
    var binProgress: Float
    var primaryAction: PrimaryAction
    var canDock: Bool
    var canEmptyBin: Bool
    var connectionText: String
    var isConnected: Bool
    var canReconnect: Bool
}

protocol HomePresentable: Presentable {
    var listener: HomePresentableListener? { get set }
    func render(_ viewModel: HomeViewModel)
    func showError(_ message: String)
}

protocol HomePresentableListener: AnyObject {
    func didTapStart(mode: CleaningMode)
    func didTapPause()
    func didTapResume()
    func didTapDock()
    func didTapEmptyBin()
    func didTapReconnect()
}

final class HomeInteractor: PresentableInteractor<HomePresentable>, HomeInteractable, HomePresentableListener {

    weak var router: HomeRouting?
    weak var listener: HomeListener?

    private let stream: RobotStateStreaming

    init(presenter: HomePresentable, stream: RobotStateStreaming) {
        self.stream = stream
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()

        Observable.combineLatest(stream.state, stream.connection)
            .map(Self.makeViewModel)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.presenter.render($0) })
            .disposeOnDeactivate(interactor: self)

        stream.errors
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.presenter.showError($0) })
            .disposeOnDeactivate(interactor: self)
    }

    // MARK: - HomePresentableListener

    func didTapStart(mode: CleaningMode) { listener?.homeDidRequest(.start(mode)) }
    func didTapPause() { listener?.homeDidRequest(.pause) }
    func didTapResume() { listener?.homeDidRequest(.resume) }
    func didTapDock() { listener?.homeDidRequest(.returnToDock) }
    func didTapEmptyBin() { listener?.homeDidRequest(.emptyBin) }
    func didTapReconnect() { listener?.homeDidRequestReconnect() }

    // MARK: - Presentation mapping

    static func makeViewModel(state: RobotState, connection: ConnectionState) -> HomeViewModel {
        let connected = connection == .connected
        let title: String
        var detail: String
        let primary: HomeViewModel.PrimaryAction
        switch state.status {
        case .docked: title = "Docked"; detail = "Ready to clean"; primary = .start
        case .charging: title = "Charging"; detail = "Battery \(state.batteryPercent)%"; primary = .start
        case .cleaning:
            title = "Cleaning"
            detail = "\(state.mode.displayName) · \(String(format: "%.1f", state.areaCleaned)) m²"
            primary = .pause
        case .paused: title = "Paused"; detail = "\(state.mode.displayName) run on hold"; primary = .resume
        case .returningToDock: title = "Returning to dock"; detail = "Almost home"; primary = .none
        case .error: title = "Needs attention"; detail = state.errorMessage ?? "Unknown error"; primary = .none
        }
        if !connected { detail = "Not available while offline" }

        let connectionText: String
        switch connection {
        case .connecting: connectionText = "Connecting…"
        case .connected: connectionText = "Connected"
        case .disconnected: connectionText = "Disconnected"
        }

        let busy = state.status == .cleaning || state.status == .paused
        return HomeViewModel(
            statusTitle: connected ? title : "Offline",
            statusDetail: detail,
            batteryText: "Battery \(state.batteryPercent)%",
            batteryProgress: Float(state.batteryPercent) / 100,
            binText: "Bin \(state.binPercent)%",
            binProgress: Float(state.binPercent) / 100,
            primaryAction: connected ? primary : .none,
            canDock: connected && (busy || state.status == .error),
            canEmptyBin: connected && state.status != .cleaning && state.binPercent > 0,
            connectionText: connectionText,
            isConnected: connected,
            canReconnect: connection == .disconnected)
    }
}

protocol HomeInteractable: Interactable {
    var router: HomeRouting? { get set }
    var listener: HomeListener? { get set }
}
