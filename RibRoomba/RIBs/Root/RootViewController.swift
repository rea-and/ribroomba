import RIBs
import UIKit

/// Passive container. Shows exactly one piece of content at a time and cross-fades between them.
final class RootViewController: UIViewController, RootPresentable, RootViewControllable {

    private var content: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    func setContent(_ viewController: ViewControllable, embeddedInNavigation: Bool) {
        loadViewIfNeeded()
        let new: UIViewController = embeddedInNavigation
            ? UINavigationController(rootViewController: viewController.uiviewController)
            : viewController.uiviewController
        guard new !== content else { return }
        let old = content
        old?.willMove(toParent: nil)
        addChild(new)
        new.view.frame = view.bounds
        new.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let old = old, window != nil {
            transition(from: old, to: new, duration: 0.25, options: .transitionCrossDissolve, animations: nil) { _ in
                old.removeFromParent()
                new.didMove(toParent: self)
            }
        } else {
            old?.view.removeFromSuperview()
            old?.removeFromParent()
            view.addSubview(new.view)
            new.didMove(toParent: self)
        }
        content = new
    }

    func setTabs(_ viewControllers: [ViewControllable]) {
        let tabs = TabsViewController()
        tabs.setViewControllers(viewControllers.map { UINavigationController(rootViewController: $0.uiviewController) },
                                animated: false)
        setContent(tabs, embeddedInNavigation: false)
    }

    private var window: UIWindow? { viewIfLoaded?.window }
}

private final class TabsViewController: UITabBarController, ViewControllable {}
