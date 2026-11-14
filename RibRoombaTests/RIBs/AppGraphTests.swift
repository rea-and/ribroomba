import RIBs
import UIKit
import XCTest
@testable import RibRoomba

/// Builds the real, Needle-wired RIB tree. Fails at runtime if `NeedleGenerated.swift` is stale or a provider is
/// missing (Needle traps on an unresolved dependency).
final class AppGraphTests: XCTestCase {

    func testRootGraphLaunchesAndAttachesAnAuthSubtree() {
        registerProviderFactories()
        let router = RootComponent().rootBuilder.build()
        router.launch(from: UIWindow(frame: UIScreen.main.bounds))
        drainMainQueue()
        XCTAssertEqual((router as? Router<RootInteractable>)?.children.count, 1)
    }

    func testEveryLoggedInDependencyResolves() {
        registerProviderFactories()
        let root = RootComponent()
        let host = HostingSpy()
        let user = User(id: "u", name: "U", email: "u@x.io")
        let router = root.loggedInBuilder.build(withListener: ListenerStub(), user: user, host: host)
        router.interactable.activate()
        router.load()
        XCTAssertEqual(router.children.count, 1, "devices list is attached first")
        XCTAssertEqual(host.contentSetCount, 1)
    }
}

private final class ListenerStub: LoggedInListener {
    func loggedInDidRequestSignOut() {}
}

private final class HostingSpy: ContentHosting {
    private(set) var contentSetCount = 0
    func setContent(_ viewController: ViewControllable, embeddedInNavigation: Bool) { contentSetCount += 1 }
    func setTabs(_ viewControllers: [ViewControllable]) {}
}
