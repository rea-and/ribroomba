import NeedleFoundation

protocol AddDeviceDependency: Dependency {
    var deviceManager: DeviceManaging { get }
}

final class AddDeviceComponent: Component<AddDeviceDependency> {}
