import NeedleFoundation

protocol DevicesDependency: Dependency {
    var deviceManager: DeviceManaging { get }
}

final class DevicesComponent: Component<DevicesDependency> {

    var addDeviceBuilder: AddDeviceBuildable {
        return AddDeviceBuilder(dependency: AddDeviceComponent(parent: self))
    }
}
