import Foundation
import RIBs
import RxSwift

protocol SettingsRouting: ViewableRouting {}

struct SettingsViewModel: Equatable {
    let name: String
    let suction: SuctionPower
    let carpetBoost: Bool
    let connectionText: String
    let isEditable: Bool
}

protocol SettingsPresentable: Presentable {
    var listener: SettingsPresentableListener? { get set }
    func render(_ viewModel: SettingsViewModel)
}

protocol SettingsPresentableListener: AnyObject {
    func didChangeName(_ name: String)
    func didChangeSuction(_ suction: SuctionPower)
    func didChangeCarpetBoost(_ enabled: Bool)
    func didTapSwitchDevice()
    func didTapSignOut()
}

protocol SettingsInteractable: Interactable {
    var router: SettingsRouting? { get set }
    var listener: SettingsListener? { get set }
}

final class SettingsInteractor: PresentableInteractor<SettingsPresentable>, SettingsInteractable, SettingsPresentableListener {

    weak var router: SettingsRouting?
    weak var listener: SettingsListener?

    private let stream: RobotStateStreaming
    private var current = RobotSettings.default
    private var lastViewModel: SettingsViewModel?

    init(presenter: SettingsPresentable, stream: RobotStateStreaming) {
        self.stream = stream
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        Observable.combineLatest(stream.settings, stream.connection)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] settings, connection in
                self?.current = settings
                let viewModel = SettingsViewModel(
                    name: settings.name, suction: settings.suction, carpetBoost: settings.carpetBoost,
                    connectionText: connection == .connected ? "Connected" : "Not connected",
                    isEditable: connection == .connected)
                self?.lastViewModel = viewModel
                self?.presenter.render(viewModel)
            })
            .disposeOnDeactivate(interactor: self)
    }

    func didChangeName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != current.name else {
            // Re-render the stored value so the view reverts an empty/unchanged edit.
            if let lastViewModel = lastViewModel { presenter.render(lastViewModel) }
            return
        }
        update { $0.name = trimmed }
    }

    func didChangeSuction(_ suction: SuctionPower) { update { $0.suction = suction } }

    func didChangeCarpetBoost(_ enabled: Bool) { update { $0.carpetBoost = enabled } }

    func didTapSwitchDevice() { listener?.settingsDidRequestSwitchDevice() }

    func didTapSignOut() { listener?.settingsDidRequestSignOut() }

    private func update(_ change: (inout RobotSettings) -> Void) {
        var next = current
        change(&next)
        guard next != current else { return }
        listener?.settingsDidChange(next)
    }
}
