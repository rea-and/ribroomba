import Foundation
import RIBs
import RxSwift

protocol DevicesRouting: ViewableRouting {
    func routeToAddDevice()
    func dismissAddDevice()
}

struct DeviceRowViewModel: Equatable {
    let id: String
    let name: String
    let subtitle: String
}

struct DevicesViewModel: Equatable {
    let greeting: String
    let rows: [DeviceRowViewModel]
    var isEmpty: Bool { rows.isEmpty }
}

protocol DevicesPresentable: Presentable {
    var listener: DevicesPresentableListener? { get set }
    func render(_ viewModel: DevicesViewModel)
    func showError(_ message: String)
}

protocol DevicesPresentableListener: AnyObject {
    func didTapAdd()
    func didSelect(id: String)
    func didDelete(id: String)
    func didTapSignOut()
}

protocol DevicesInteractable: Interactable, AddDeviceListener {
    var router: DevicesRouting? { get set }
    var listener: DevicesListener? { get set }
}

final class DevicesInteractor: PresentableInteractor<DevicesPresentable>, DevicesInteractable, DevicesPresentableListener {

    weak var router: DevicesRouting?
    weak var listener: DevicesListener?

    private let user: User
    private let deviceManager: DeviceManaging
    private var devices: [Device] = []

    init(presenter: DevicesPresentable, user: User, deviceManager: DeviceManaging) {
        self.user = user
        self.deviceManager = deviceManager
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        let greeting = "Signed in as \(user.name)"
        deviceManager.pairedDevices
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] devices in
                self?.devices = devices
                self?.presenter.render(Self.makeViewModel(greeting: greeting, devices: devices))
            })
            .disposeOnDeactivate(interactor: self)
    }

    // MARK: - DevicesPresentableListener

    func didTapAdd() { router?.routeToAddDevice() }

    func didSelect(id: String) {
        guard let device = devices.first(where: { $0.id == id }) else { return }
        listener?.devicesDidSelect(device)
    }

    func didDelete(id: String) {
        guard let device = devices.first(where: { $0.id == id }) else { return }
        deviceManager.remove(device)
            .observe(on: MainScheduler.instance)
            .subscribe(onError: { [weak self] in self?.presenter.showError($0.localizedDescription) })
            .disposeOnDeactivate(interactor: self)
    }

    func didTapSignOut() { listener?.devicesDidRequestSignOut() }

    // MARK: - AddDeviceListener

    func addDeviceDidAdd(_ device: Device) { router?.dismissAddDevice() }

    func addDeviceDidCancel() { router?.dismissAddDevice() }

    static func makeViewModel(greeting: String, devices: [Device]) -> DevicesViewModel {
        DevicesViewModel(greeting: greeting, rows: devices.map {
            DeviceRowViewModel(id: $0.id, name: $0.name, subtitle: $0.model)
        })
    }
}
