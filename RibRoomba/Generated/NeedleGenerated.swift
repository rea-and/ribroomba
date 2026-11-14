

import NeedleFoundation

// swiftlint:disable unused_declaration
private let needleDependenciesHash : String? = nil

// MARK: - Traversal Helpers

private func parent1(_ component: NeedleFoundation.Scope) -> NeedleFoundation.Scope {
    return component.parent
}

private func parent2(_ component: NeedleFoundation.Scope) -> NeedleFoundation.Scope {
    return component.parent.parent
}

private func parent3(_ component: NeedleFoundation.Scope) -> NeedleFoundation.Scope {
    return component.parent.parent.parent
}

// MARK: - Providers

#if !NEEDLE_DYNAMIC

private class SettingsDependencybc2e6a1e60afec3024f8Provider: SettingsDependency {
    var robotStateStream: RobotStateStreaming {
        return sessionComponent.robotStateStream
    }
    private let sessionComponent: SessionComponent
    init(sessionComponent: SessionComponent) {
        self.sessionComponent = sessionComponent
    }
}
/// ^->RootComponent->LoggedInComponent->SessionComponent->SettingsComponent
private func factoryda9a75873e7ae1b0ba745bb94a2296eb03e65afd(_ component: NeedleFoundation.Scope) -> AnyObject {
    return SettingsDependencybc2e6a1e60afec3024f8Provider(sessionComponent: parent1(component) as! SessionComponent)
}
private class HomeDependencyce47d1f41a2f578b1e9dProvider: HomeDependency {
    var robotStateStream: RobotStateStreaming {
        return sessionComponent.robotStateStream
    }
    private let sessionComponent: SessionComponent
    init(sessionComponent: SessionComponent) {
        self.sessionComponent = sessionComponent
    }
}
/// ^->RootComponent->LoggedInComponent->SessionComponent->HomeComponent
private func factorybefc6185de77846ac7945bb94a2296eb03e65afd(_ component: NeedleFoundation.Scope) -> AnyObject {
    return HomeDependencyce47d1f41a2f578b1e9dProvider(sessionComponent: parent1(component) as! SessionComponent)
}
private class ScheduleDependency564bc0b29cfdb7d7e346Provider: ScheduleDependency {
    var robotStateStream: RobotStateStreaming {
        return sessionComponent.robotStateStream
    }
    private let sessionComponent: SessionComponent
    init(sessionComponent: SessionComponent) {
        self.sessionComponent = sessionComponent
    }
}
/// ^->RootComponent->LoggedInComponent->SessionComponent->ScheduleComponent
private func factorydff46a33261f7fcc8e005bb94a2296eb03e65afd(_ component: NeedleFoundation.Scope) -> AnyObject {
    return ScheduleDependency564bc0b29cfdb7d7e346Provider(sessionComponent: parent1(component) as! SessionComponent)
}
private class LoggedOutDependencyacada53ea78d270efa2fProvider: LoggedOutDependency {
    var authService: AuthServicing {
        return rootComponent.authService
    }
    private let rootComponent: RootComponent
    init(rootComponent: RootComponent) {
        self.rootComponent = rootComponent
    }
}
/// ^->RootComponent->LoggedOutComponent
private func factory1434ff4463106e5c4f1bb3a8f24c1d289f2c0f2e(_ component: NeedleFoundation.Scope) -> AnyObject {
    return LoggedOutDependencyacada53ea78d270efa2fProvider(rootComponent: parent1(component) as! RootComponent)
}
private class LoggedInDependency637c07bfce1b5ccf0a6eProvider: LoggedInDependency {
    var deviceManager: DeviceManaging {
        return rootComponent.deviceManager
    }
    private let rootComponent: RootComponent
    init(rootComponent: RootComponent) {
        self.rootComponent = rootComponent
    }
}
/// ^->RootComponent->LoggedInComponent
private func factory2d08e87342cecea575b3b3a8f24c1d289f2c0f2e(_ component: NeedleFoundation.Scope) -> AnyObject {
    return LoggedInDependency637c07bfce1b5ccf0a6eProvider(rootComponent: parent1(component) as! RootComponent)
}
private class SessionDependency298d117e02a62bf7a640Provider: SessionDependency {
    var deviceManager: DeviceManaging {
        return rootComponent.deviceManager
    }
    private let rootComponent: RootComponent
    init(rootComponent: RootComponent) {
        self.rootComponent = rootComponent
    }
}
/// ^->RootComponent->LoggedInComponent->SessionComponent
private func factoryd5c0eef8a79da8517407a9403e3301bb54f80df0(_ component: NeedleFoundation.Scope) -> AnyObject {
    return SessionDependency298d117e02a62bf7a640Provider(rootComponent: parent2(component) as! RootComponent)
}
private class HistoryDependency1f9cc8e686513d3e7b13Provider: HistoryDependency {
    var robotStateStream: RobotStateStreaming {
        return sessionComponent.robotStateStream
    }
    private let sessionComponent: SessionComponent
    init(sessionComponent: SessionComponent) {
        self.sessionComponent = sessionComponent
    }
}
/// ^->RootComponent->LoggedInComponent->SessionComponent->HistoryComponent
private func factory59a0353f5f9288773ed05bb94a2296eb03e65afd(_ component: NeedleFoundation.Scope) -> AnyObject {
    return HistoryDependency1f9cc8e686513d3e7b13Provider(sessionComponent: parent1(component) as! SessionComponent)
}
private class AddDeviceDependency06f1f10a97f1f3ce9be5Provider: AddDeviceDependency {
    var deviceManager: DeviceManaging {
        return rootComponent.deviceManager
    }
    private let rootComponent: RootComponent
    init(rootComponent: RootComponent) {
        self.rootComponent = rootComponent
    }
}
/// ^->RootComponent->LoggedInComponent->DevicesComponent->AddDeviceComponent
private func factorydf1b1948576bb820dadc42f5655bf2362a8495f6(_ component: NeedleFoundation.Scope) -> AnyObject {
    return AddDeviceDependency06f1f10a97f1f3ce9be5Provider(rootComponent: parent3(component) as! RootComponent)
}
private class DevicesDependency498e037c8c03476cca3cProvider: DevicesDependency {
    var deviceManager: DeviceManaging {
        return rootComponent.deviceManager
    }
    private let rootComponent: RootComponent
    init(rootComponent: RootComponent) {
        self.rootComponent = rootComponent
    }
}
/// ^->RootComponent->LoggedInComponent->DevicesComponent
private func factory8f1d8eba51322aec10a4a9403e3301bb54f80df0(_ component: NeedleFoundation.Scope) -> AnyObject {
    return DevicesDependency498e037c8c03476cca3cProvider(rootComponent: parent2(component) as! RootComponent)
}

#else
extension ScheduleEditorComponent: NeedleFoundation.Registration {
    public func registerItems() {

    }
}
extension SettingsComponent: NeedleFoundation.Registration {
    public func registerItems() {
        keyPathToName[\SettingsDependency.robotStateStream] = "robotStateStream-RobotStateStreaming"
    }
}
extension HomeComponent: NeedleFoundation.Registration {
    public func registerItems() {
        keyPathToName[\HomeDependency.robotStateStream] = "robotStateStream-RobotStateStreaming"
    }
}
extension ScheduleComponent: NeedleFoundation.Registration {
    public func registerItems() {
        keyPathToName[\ScheduleDependency.robotStateStream] = "robotStateStream-RobotStateStreaming"

    }
}
extension LoggedOutComponent: NeedleFoundation.Registration {
    public func registerItems() {
        keyPathToName[\LoggedOutDependency.authService] = "authService-AuthServicing"
    }
}
extension LoggedInComponent: NeedleFoundation.Registration {
    public func registerItems() {
        keyPathToName[\LoggedInDependency.deviceManager] = "deviceManager-DeviceManaging"

    }
}
extension SessionComponent: NeedleFoundation.Registration {
    public func registerItems() {
        keyPathToName[\SessionDependency.deviceManager] = "deviceManager-DeviceManaging"
        localTable["robotStateStream-RobotStateStreaming"] = { [unowned self] in self.robotStateStream as Any }
    }
}
extension HistoryComponent: NeedleFoundation.Registration {
    public func registerItems() {
        keyPathToName[\HistoryDependency.robotStateStream] = "robotStateStream-RobotStateStreaming"
    }
}
extension RootComponent: NeedleFoundation.Registration {
    public func registerItems() {

        localTable["authService-AuthServicing"] = { [unowned self] in self.authService as Any }
        localTable["deviceManager-DeviceManaging"] = { [unowned self] in self.deviceManager as Any }
    }
}
extension AddDeviceComponent: NeedleFoundation.Registration {
    public func registerItems() {
        keyPathToName[\AddDeviceDependency.deviceManager] = "deviceManager-DeviceManaging"
    }
}
extension DevicesComponent: NeedleFoundation.Registration {
    public func registerItems() {
        keyPathToName[\DevicesDependency.deviceManager] = "deviceManager-DeviceManaging"

    }
}


#endif

private func factoryEmptyDependencyProvider(_ component: NeedleFoundation.Scope) -> AnyObject {
    return EmptyDependencyProvider(component: component)
}

// MARK: - Registration
private func registerProviderFactory(_ componentPath: String, _ factory: @escaping (NeedleFoundation.Scope) -> AnyObject) {
    __DependencyProviderRegistry.instance.registerDependencyProviderFactory(for: componentPath, factory)
}

#if !NEEDLE_DYNAMIC

@inline(never) private func register1() {
    registerProviderFactory("^->RootComponent->LoggedInComponent->SessionComponent->ScheduleComponent->ScheduleEditorComponent", factoryEmptyDependencyProvider)
    registerProviderFactory("^->RootComponent->LoggedInComponent->SessionComponent->SettingsComponent", factoryda9a75873e7ae1b0ba745bb94a2296eb03e65afd)
    registerProviderFactory("^->RootComponent->LoggedInComponent->SessionComponent->HomeComponent", factorybefc6185de77846ac7945bb94a2296eb03e65afd)
    registerProviderFactory("^->RootComponent->LoggedInComponent->SessionComponent->ScheduleComponent", factorydff46a33261f7fcc8e005bb94a2296eb03e65afd)
    registerProviderFactory("^->RootComponent->LoggedOutComponent", factory1434ff4463106e5c4f1bb3a8f24c1d289f2c0f2e)
    registerProviderFactory("^->RootComponent->LoggedInComponent", factory2d08e87342cecea575b3b3a8f24c1d289f2c0f2e)
    registerProviderFactory("^->RootComponent->LoggedInComponent->SessionComponent", factoryd5c0eef8a79da8517407a9403e3301bb54f80df0)
    registerProviderFactory("^->RootComponent->LoggedInComponent->SessionComponent->HistoryComponent", factory59a0353f5f9288773ed05bb94a2296eb03e65afd)
    registerProviderFactory("^->RootComponent", factoryEmptyDependencyProvider)
    registerProviderFactory("^->RootComponent->LoggedInComponent->DevicesComponent->AddDeviceComponent", factorydf1b1948576bb820dadc42f5655bf2362a8495f6)
    registerProviderFactory("^->RootComponent->LoggedInComponent->DevicesComponent", factory8f1d8eba51322aec10a4a9403e3301bb54f80df0)
}
#endif

public func registerProviderFactories() {
#if !NEEDLE_DYNAMIC
    register1()
#endif
}
