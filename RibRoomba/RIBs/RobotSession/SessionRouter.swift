import RIBs

/// Viewless router: attaches the four feature RIBs and hands their views to the parent-provided container.
final class SessionRouter: Router<SessionInteractable>, SessionRouting {

    private let host: ContentHosting
    private let homeBuilder: HomeBuildable
    private let scheduleBuilder: ScheduleBuildable
    private let historyBuilder: HistoryBuildable
    private let settingsBuilder: SettingsBuildable

    init(interactor: SessionInteractable,
         host: ContentHosting,
         homeBuilder: HomeBuildable,
         scheduleBuilder: ScheduleBuildable,
         historyBuilder: HistoryBuildable,
         settingsBuilder: SettingsBuildable) {
        self.host = host
        self.homeBuilder = homeBuilder
        self.scheduleBuilder = scheduleBuilder
        self.historyBuilder = historyBuilder
        self.settingsBuilder = settingsBuilder
        super.init(interactor: interactor)
        interactor.router = self
    }

    override func didLoad() {
        super.didLoad()
        let children: [ViewableRouting] = [
            homeBuilder.build(withListener: interactor),
            scheduleBuilder.build(withListener: interactor),
            historyBuilder.build(withListener: interactor),
            settingsBuilder.build(withListener: interactor),
        ]
        children.forEach(attachChild)
        host.setTabs(children.map(\.viewControllable))
    }
}
