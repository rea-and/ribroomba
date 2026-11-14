import RIBs

protocol SettingsListener: AnyObject {
    func settingsDidChange(_ settings: RobotSettings)
    func settingsDidRequestSwitchDevice()
    func settingsDidRequestSignOut()
}

protocol SettingsBuildable: Buildable {
    func build(withListener listener: SettingsListener) -> ViewableRouting
}

final class SettingsBuilder: Builder<SettingsComponent>, SettingsBuildable {

    func build(withListener listener: SettingsListener) -> ViewableRouting {
        let viewController = SettingsViewController()
        let interactor = SettingsInteractor(presenter: viewController, stream: dependency.dependency.robotStateStream)
        interactor.listener = listener
        return SettingsRouter(interactor: interactor, viewController: viewController)
    }
}
