import RIBs
import UIKit

/// Builds the RIB tree for each window scene and launches it.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var launchRouter: LaunchRouting?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let router = RootComponent().rootBuilder.build()
        launchRouter = router
        router.launch(from: window)
    }
}
