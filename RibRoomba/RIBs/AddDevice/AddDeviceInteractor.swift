import RIBs
import RxSwift

protocol AddDeviceRouting: ViewableRouting {}

struct DiscoveredRowViewModel: Equatable {
    let id: String
    let name: String
    let subtitle: String
    let signalBars: Int
    let isPairing: Bool
}

struct AddDeviceViewModel: Equatable {
    let isScanning: Bool
    let isPairing: Bool
    let rows: [DiscoveredRowViewModel]
    let errorMessage: String?

    var statusText: String {
        if isPairing { return "Pairing…" }
        if isScanning { return "Searching for robots nearby…" }
        return rows.isEmpty ? "No new robots found. Make sure it's powered on and close by." : "Tap a robot to add it."
    }
}

protocol AddDevicePresentable: Presentable {
    var listener: AddDevicePresentableListener? { get set }
    func render(_ viewModel: AddDeviceViewModel)
}

protocol AddDevicePresentableListener: AnyObject {
    func didSelect(id: String)
    func didTapRescan()
    func didTapCancel()
}

protocol AddDeviceInteractable: Interactable {
    var router: AddDeviceRouting? { get set }
    var listener: AddDeviceListener? { get set }
}

/// Searches for nearby robots and pairs the one the user picks.
final class AddDeviceInteractor: PresentableInteractor<AddDevicePresentable>, AddDeviceInteractable, AddDevicePresentableListener {

    weak var router: AddDeviceRouting?
    weak var listener: AddDeviceListener?

    private let deviceManager: DeviceManaging
    private let scanDisposable = SerialDisposable()
    private var discovered: [DiscoveredDevice] = []
    private var isScanning = false
    private var pairingID: String?
    private var errorMessage: String?

    init(presenter: AddDevicePresentable, deviceManager: DeviceManaging) {
        self.deviceManager = deviceManager
        super.init(presenter: presenter)
        presenter.listener = self
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        _ = scanDisposable.disposeOnDeactivate(interactor: self)
        startScan()
    }

    // MARK: - AddDevicePresentableListener

    func didTapRescan() {
        guard pairingID == nil, !isScanning else { return }
        startScan()
    }

    func didTapCancel() { listener?.addDeviceDidCancel() }

    func didSelect(id: String) {
        guard pairingID == nil, let target = discovered.first(where: { $0.id == id }) else { return }
        pairingID = id
        errorMessage = nil
        render()
        deviceManager.add(target)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onSuccess: { [weak self] device in
                    self?.pairingID = nil
                    self?.listener?.addDeviceDidAdd(device)
                },
                onFailure: { [weak self] error in
                    self?.pairingID = nil
                    self?.errorMessage = error.localizedDescription
                    self?.render()
                })
            .disposeOnDeactivate(interactor: self)
    }

    // MARK: - Private

    private func startScan() {
        isScanning = true
        errorMessage = nil
        discovered = []
        render()
        scanDisposable.disposable = deviceManager.scan()
            .observe(on: MainScheduler.instance)
            .subscribe(
                onNext: { [weak self] in self?.discovered = $0; self?.render() },
                onError: { [weak self] in self?.isScanning = false; self?.errorMessage = $0.localizedDescription; self?.render() },
                onCompleted: { [weak self] in self?.isScanning = false; self?.render() })
    }

    private func render() {
        presenter.render(AddDeviceViewModel(
            isScanning: isScanning,
            isPairing: pairingID != nil,
            rows: discovered.map {
                DiscoveredRowViewModel(id: $0.id, name: $0.name, subtitle: $0.model,
                                       signalBars: $0.signalStrength, isPairing: $0.id == pairingID)
            },
            errorMessage: errorMessage))
    }
}

private extension SerialDisposable {
    /// Ties a long-lived serial subscription to the interactor's active scope.
    func disposeOnDeactivate(interactor: Interactor) -> Disposable {
        (self as Disposable).disposeOnDeactivate(interactor: interactor)
    }
}
