import Foundation
import RxRelay
import RxSwift

// MARK: - Contract

/// A robot the user has added to their account.
public struct Device: Codable, Equatable {
    public let id: String
    public let name: String
    public let model: String
}

/// A robot found while searching nearby, not yet added.
public struct DiscoveredDevice: Equatable {
    public let id: String
    public let name: String
    public let model: String
    /// 1 (weak) … 4 (strong).
    public let signalStrength: Int
}

public enum DeviceError: Error, LocalizedError, Equatable {
    case alreadyAdded
    case pairingFailed

    public var errorDescription: String? {
        switch self {
        case .alreadyAdded: return "This robot has already been added."
        case .pairingFailed: return "Couldn't pair with the robot. Move closer and try again."
        }
    }
}

/// Device search / pairing / registry abstraction. It is also the factory for per-device connectors, so swapping
/// the mock for a real BLE/Wi-Fi stack never touches a RIB.
public protocol DeviceManaging: AnyObject {
    /// Devices added to the account. Replays the latest value.
    var pairedDevices: Observable<[Device]> { get }
    /// Searches nearby. Emits the cumulative list of found devices (not yet added), then completes.
    func scan() -> Observable<[DiscoveredDevice]>
    func add(_ discovered: DiscoveredDevice) -> Single<Device>
    func remove(_ device: Device) -> Completable
    /// The connection to one specific device. Repeated calls for the same device return the same connector.
    func connector(for device: Device) -> RobotConnecting
}

// MARK: - Mock

final class MockDeviceManager: DeviceManaging {

    static let nearby: [DiscoveredDevice] = [
        DiscoveredDevice(id: "rib-r1-a3f2", name: "Living Room Rib", model: "RibRoomba R1", signalStrength: 4),
        DiscoveredDevice(id: "rib-r1-77c0", name: "Rib R1-77C0", model: "RibRoomba R1", signalStrength: 3),
        DiscoveredDevice(id: "rib-r2-9d41", name: "Rib R2-9D41", model: "RibRoomba R2 Max", signalStrength: 2),
        DiscoveredDevice(id: "rib-r2-0be8", name: "Garage Rib", model: "RibRoomba R2 Max", signalStrength: 1),
    ]

    private static let storageKey = "mock.devices.paired"

    private let defaults: UserDefaults?
    private let scanStep: RxTimeInterval
    private let pairingDelay: RxTimeInterval
    private let scheduler: SchedulerType
    private let makeConnector: (Device) -> RobotConnecting
    private let pairedRelay = BehaviorRelay<[Device]>(value: [])
    private var connectors: [String: RobotConnecting] = [:]

    var pairedDevices: Observable<[Device]> { pairedRelay.asObservable() }

    init(defaults: UserDefaults? = .standard,
         scanStep: RxTimeInterval = .milliseconds(900),
         pairingDelay: RxTimeInterval = .milliseconds(1500),
         scheduler: SchedulerType = MainScheduler.instance,
         makeConnector: ((Device) -> RobotConnecting)? = nil) {
        self.defaults = defaults
        self.scanStep = scanStep
        self.pairingDelay = pairingDelay
        self.scheduler = scheduler
        self.makeConnector = makeConnector ?? { MockRobotConnector(deviceID: $0.id, deviceName: $0.name, defaults: defaults) }
        if let data = defaults?.data(forKey: Self.storageKey), let devices = try? JSONDecoder().decode([Device].self, from: data) {
            pairedRelay.accept(devices)
        }
    }

    func scan() -> Observable<[DiscoveredDevice]> {
        Observable.deferred { [self] in
            let pairedIDs = Set(pairedRelay.value.map(\.id))
            let pool = Self.nearby.filter { !pairedIDs.contains($0.id) }
            return Observable<Int>.interval(scanStep, scheduler: scheduler)
                .take(pool.count)
                .map { Array(pool.prefix($0 + 1)) }
                .startWith([])
        }
    }

    func add(_ discovered: DiscoveredDevice) -> Single<Device> {
        Single<Int>.timer(pairingDelay, scheduler: scheduler).map { [self] _ in
            guard !pairedRelay.value.contains(where: { $0.id == discovered.id }) else { throw DeviceError.alreadyAdded }
            let device = Device(id: discovered.id, name: discovered.name, model: discovered.model)
            let updated = pairedRelay.value + [device]
            pairedRelay.accept(updated)
            persist(updated)
            return device
        }
    }

    func remove(_ device: Device) -> Completable {
        Completable.create { [weak self] completable in
            guard let self = self else { completable(.completed); return Disposables.create() }
            let updated = self.pairedRelay.value.filter { $0.id != device.id }
            self.pairedRelay.accept(updated)
            self.persist(updated)
            self.connectors[device.id] = nil
            completable(.completed)
            return Disposables.create()
        }
    }

    func connector(for device: Device) -> RobotConnecting {
        if let existing = connectors[device.id] { return existing }
        let created = makeConnector(device)
        connectors[device.id] = created
        return created
    }

    private func persist(_ devices: [Device]) {
        if let data = try? JSONEncoder().encode(devices) { defaults?.set(data, forKey: Self.storageKey) }
    }
}
