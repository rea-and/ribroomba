# RIBs — interview cheat sheet

A simplified, speakable explanation of the RIBs architecture (Uber), with Needle for DI and RxSwift for streams. Every
concept is tied to a concrete example from this project (RibRoomba) so you can answer with "in my app I did…".

> Sections 1–2 are the 30-second answer. 3–7 are the building blocks, 8 is who-talks-to-whom, 9 streams, 10 DI,
> 11 lifecycle. 12 is a Q&A bank, 13 traps and honest trade-offs, 14 a 60-second recap script.

---

## 1. The 30-second pitch

> RIBs stands for **Router, Interactor, Builder**. The app is a **tree of RIBs**, and that tree — not the view
> hierarchy — is the source of truth for *what state the app is in*. Each RIB is a small unit of business logic with an
> optional view. The **Interactor** holds the business logic, the **Router** attaches and detaches child RIBs, the
> **Builder** wires everything together with its dependencies, and the view is **passive**. When a RIB is detached, its
> whole subtree is deactivated and every subscription inside it is cancelled automatically. It scales well in big teams
> because every unit has one job, dependencies are explicit, and the logic is testable without any UI.

## 2. The mental model in one picture

```
                Builder  ── creates ──►  Router ◄──── owns ───► child Routers (the tree)
                   │                       │
                   │ creates               │ talks to (weak)
                   ▼                       ▼
              Interactor  ◄── listener ──  parent's Interactor        business logic lives here
                   │  ▲
        renders via│  │ user actions via
       Presentable │  │ PresentableListener
                   ▼  │
                 View (passive UIViewController)
```

Three rules cover most of the architecture:

1. **Logic in the Interactor. Navigation in the Router. Rendering in the View.**
2. **Children talk to parents only through a `Listener` protocol; parents talk to children only through the Builder's
   arguments** (and DI). Nobody reaches sideways to a sibling.
3. **Anything alive in a RIB is tied to that RIB's lifetime.** Detach the RIB → everything it started stops.

---

## 3. The building blocks (what each one is, in one line)

| Block | One-liner | Lives where in this project |
|---|---|---|
| **RIB** | One node of the tree: Router + Interactor + Builder (+ optional View) + its DI Component | `RibRoomba/RIBs/<Name>/` |
| **Builder** | The *only* place that instantiates the RIB's parts; receives dependencies, returns a Router | `HomeBuilder` |
| **Component** | The DI container for the RIB: what it **needs** (a `Dependency` protocol) and what it **offers** its children | `HomeComponent`, `SessionComponent` |
| **Interactor** | All business logic; observes streams, decides, tells the presenter what to show and the router where to go | `HomeInteractor` |
| **Router** | Attaches / detaches child RIBs and arranges presentation (push, modal, tabs). No business logic | `ScheduleRouter` |
| **Presenter / View** | Passive. Renders a view model; forwards taps. In RIBs the `UIViewController` *is* the presenter | `HomeViewController` |
| **Listener** | The weak protocol a child uses to report *up* to its parent | `HomeListener`, `DevicesListener` |
| **PresentableListener** | The protocol the view uses to report user actions to *its* interactor | `HomePresentableListener` |
| **Presentable** | The protocol the interactor uses to push view models to the view (`render(_:)`) | `HomePresentable` |
| **Routing / Interactable** | Protocols that let router and interactor talk to each other without knowing concrete types (so they're mockable) | `HomeRouting`, `HomeInteractable` |
| **View model** | A plain struct: exactly what the view needs, already formatted | `HomeViewModel`, `DeviceRowViewModel` |
| **Viewless RIB** | A RIB with no view — only logic and routing; great for scopes/state owners | `LoggedIn`, `RobotSession` |
| **LaunchRouter** | The root router that is attached to the `UIWindow` | `RootRouter` |
| **Workflow** | A chain of steps through the tree, used for deep links (RIBs framework feature) | *not used here* |
| **Worker** | A lifecycle-bound unit of logic without a view, started/stopped with an interactor | *not used here* |
| **LeakDetector** | Debug tool in the framework that checks detached RIBs/views really deallocate | built in |

**Naming trick for interviews:** "Builder builds, Router routes, Interactor interacts (thinks), Presenter presents."

---

## 4. The Interactor — the brain

* Subclass `PresentableInteractor<PresenterType>` (view-backed) or `Interactor` (viewless).
* Has **`didBecomeActive()`** and **`willResignActive()`**: the activation lifecycle. You subscribe in
  `didBecomeActive()`.
* Holds `weak var router` (to navigate) and `weak var listener` (to report to the parent).
* Never imports `UIKit`. Turns streams into **view models** and calls `presenter.render(vm)`.
* Example (`HomeInteractor`): combines `state` and `connection` streams → maps to `HomeViewModel` → renders; and turns
  a "Start" tap into `listener.homeDidRequest(.start(mode))`.

```swift
override func didBecomeActive() {
    super.didBecomeActive()
    Observable.combineLatest(stream.state, stream.connection)
        .map(Self.makeViewModel)                        // pure function: easy to unit-test
        .observe(on: MainScheduler.instance)
        .subscribe(onNext: { [weak self] in self?.presenter.render($0) })
        .disposeOnDeactivate(interactor: self)          // the lifecycle owns the subscription
}
```

## 5. The Router — the navigator

* `Router<InteractorType>` (viewless) or `ViewableRouter<Interactor, ViewController>` (with a view).
* **`attachChild(_:)`**: adds the child to `children`, **activates its interactor**, then calls `load()` (`didLoad()`).
* **`detachChild(_:)`**: **deactivates its interactor** (→ its subscriptions die) and removes it from `children`.
* Owns the *presentation* decision: "show the editor modally", "put these four VCs in tabs".
* Contains **no business logic**. The interactor says *what* (`routeToEditor`), the router does *how*.
* Parent router builds a child by calling the child's builder: `editorBuilder.build(withListener: interactor, entry:)`.

## 6. The Builder — the wiring

* Receives the dependencies (via its Component), creates **View → Interactor → Router** in that order, hooks up the
  listener, returns the Router (or `LaunchRouting`).
* The builder is the **only** place with `new`-ing of a RIB's parts → everything else just receives what it needs
  (plain dependency injection, no singletons).
* Runtime values (e.g. the selected `Device`) are **arguments of `build(...)`**; stable services come from the
  **Component**.

```swift
func build(withListener listener: HomeListener) -> ViewableRouting {
    let vc = HomeViewController()
    let interactor = HomeInteractor(presenter: vc, stream: dependency.dependency.robotStateStream)
    interactor.listener = listener
    return HomeRouter(interactor: interactor, viewController: vc)
}
```

## 7. The View — passive

* A `UIViewController` that conforms to the **Presentable** (`render(viewModel)`) and **ViewControllable** protocols.
* Forwards every user action to `PresentableListener` (`listener?.didTapStart(mode:)`); makes **no decisions**.
* Doesn't know about models, services, streams, or routers. Replaceable (UIKit ↔ SwiftUI) without touching logic.

---

## 8. Communication: who may talk to whom

```
View ──(PresentableListener)──► Interactor ──(Listener)──► Parent Interactor
View ◄──(Presentable.render)──   Interactor
Interactor ──(Routing)──► Router ──(attach/detach)──► child Routers
Parent ──(Builder.build args + DI)──► Child
```

* **Child → parent:** `Listener` protocol, `weak`. The *parent's interactor* conforms to its children's listeners and
  decides what to do. Example: `Settings` never signs the user out — it calls `settingsDidRequestSignOut()`; `Session`
  forwards it to `LoggedIn`, which forwards it to `Root`, which owns the auth service.
* **Parent → child:** builder arguments + DI. A child never holds its parent.
* **Siblings:** never talk directly; they go through the parent (or through a shared *stream* provided by the parent).
* This chain is also what makes **navigation a consequence of state**: Root observes `currentUser`, so login, restored
  session and sign-out all take one code path.

---

## 9. Streams (RxSwift) — how data and state flow

**Idea:** state is exposed as **read-only observables that replay the latest value**; changes are pushed to subscribers;
commands travel the other way through listeners.

| Concept | In this project |
|---|---|
| Hot, replaying state | `BehaviorRelay` kept **private** by its owner, exposed as `Observable` (`asObservable()`) |
| One-shot events | `PublishRelay` (e.g. transient error messages: `stream.errors`) |
| Commands | `Completable` (`connector.send(.start)`) |
| Request/response | `Single` (`authService.signIn`, `deviceManager.add`) |
| Combining | `combineLatest(state, connection)` → one view model |
| Main thread | `.observe(on: MainScheduler.instance)` before touching a view |
| Lifetime | `.disposeOnDeactivate(interactor: self)` — **no DisposeBag** in interactors |

**Mutable vs read-only (important design point):** the session scope owns a `MutableRobotStateStream` (only the
`SessionInteractor` can write) but hands children only a `RobotStateStreaming` protocol with `Observable`s. Children can
*read* state and *ask* for changes via a listener, but can never write it.

**Cold vs hot:** `Single`/`Completable` from services are **cold** — nothing happens until subscribed. Relays are
**hot** — values flow regardless of subscribers (but a `BehaviorRelay` replays the last one).

**Why replay matters:** a freshly attached RIB (e.g. when the History tab is built) renders immediately from the current
value; no "initial load" call is needed.

**Reactive flow for one action (cleaning run), end to end:**

```
tap Start → View → Interactor → (HomeListener) → SessionInteractor → connector.send(.start)
connector.stateRelay ─► SessionInteractor mirrors ─► MutableRobotStateStream ─► (read-only) ─► HomeInteractor
   ─► combineLatest ─► makeViewModel ─► observe(on: Main) ─► presenter.render ─► View
```

---

## 10. Dependency injection (Needle)

**What problem it solves:** each RIB needs services (auth, devices, state streams). Passing them by hand through every
parent→child constructor is noisy and error-prone, and singletons hurt testability. **Needle** gives *scoped,
compile-time-checked* DI.

**How it works:**

* **Component** = a scope. `final class HomeComponent: Component<HomeDependency>`.
* **Dependency protocol** = *what the RIB needs from ancestors*, as read-only properties:
  `protocol HomeDependency: Dependency { var robotStateStream: RobotStateStreaming { get } }`.
* A **parent component provides** objects as properties (often `shared { … }` for one instance per scope) and
  **creates child components** (`HomeComponent(parent: self)`).
* **Needle's code generator** scans the sources, walks the component tree, and **generates providers** that satisfy each
  child's dependency protocol from the closest ancestor offering it. If something is missing, **generation fails** — a
  compile-time-style check, not a runtime crash.
* The generated file (`NeedleGenerated.swift`) is **checked in**; the app calls `registerProviderFactories()` once at
  launch (before any component is created).

**Scoping in this project:**

```
RootComponent         provides authService, deviceManager     (app-wide, shared)
└ LoggedInComponent
  └ SessionComponent  provides robotStateStream (read-only)   (one per device session)
    └ Home / Schedule / History / Settings   each only declares: needs robotStateStream
```

Why it's good: a child can only use what it **declares**; the connector isn't visible to feature RIBs at all; scopes
control lifetime (a new `SessionComponent` per session → a fresh stream per device).

**Components vs. Builders:** the component says *what is available*; the builder *uses* it to create the RIB's objects.

**Gotchas from real use (good "war stories"):**

1. Needle 0.25 only recognises **`public`** provider properties → the provided types must be public too.
2. RIBs and NeedleFoundation both define `Component`/`Dependency` → keep them in **separate files** (no file imports
   both).
3. Regenerate the Needle code whenever a component/dependency changes (a `--check` script can enforce it in CI).

> Interview note: Uber's RIBs originally shipped its own simple `Component`/`Dependency` (hand-written DI). **Needle is
> Uber's compile-time-checked evolution of that idea.** Same concepts: scope = component, dependency protocol, parent
> provides.

---

## 11. Lifecycle: activation, attach/detach, memory

```
Builder.build() ─► Router (not active)
parent.attachChild(router) ─► interactor.activate() ─► didBecomeActive()  ─► router.load() ─► didLoad()
…subscriptions live…
parent.detachChild(router) ─► interactor.deactivate() ─► willResignActive() ─► all disposeOnDeactivate subscriptions disposed
                           ─► router removed from children ─► (no strong refs left) ─► RIB deallocates
```

* **Ownership:** Router → Interactor, View, children. Interactor → Presenter (the view). Everything pointing *up*
  (`router`, `listener`, the view's `listener`) is **weak** → no retain cycles.
* Detaching a RIB **kills its whole subtree** and all its subscriptions — that's the main reason it's robust against
  "zombie" observers.
* **LeakDetector** asserts in debug that a detached RIB's view/interactor are actually released.
* Modal child RIBs: present when attached, dismiss + detach on the child's `didSave/didCancel`. Set
  `isModalInPresentation` so the user can't dismiss it behind the RIB's back (otherwise the view disappears while the
  RIB stays attached).

---

## 12. Q&A bank (answers you can say out loud)

**What is RIBs and why was it created?**
Uber needed an architecture for a very large app with many teams. RIBs makes **business logic the center**, models the
app as a **tree of small, independently testable units**, and keeps dependencies explicit so teams don't step on each
other.

**How is it different from MVC/MVVM?**
In MVVM the view model usually mirrors a *screen*, and navigation is typically handled by coordinators or the view
layer. In RIBs the tree represents **state and scope**, not screens; a RIB can have **no view** at all; navigation is a
**router's** job and is driven by interactors; lifecycle (activation) is built in and ties subscriptions to it.

**How does it differ from VIPER?**
Similar separation (Interactor, Presenter, Router), but RIBs adds a **tree with parent/child lifecycle**, **builders +
scoped DI**, **viewless units**, and **strict upward communication through listeners**. VIPER is typically per-screen
and flat.

**How is it different from Clean Architecture?**
Clean is a *layering principle* (dependency rule, use cases, entities). RIBs is a concrete *structure for the
presentation/application layer*. You can place Clean-style use cases/services behind the interactors (in my app:
`AuthServicing`, `DeviceManaging`, `RobotConnecting`).

**Why does the interactor not know the view?**
So the logic is testable without UIKit and the UI is replaceable. It only talks to a `Presentable` protocol and emits
view models.

**Where does navigation logic live?**
The **interactor decides** (it calls `router.routeToX()`), the **router executes** (build + attach + present). In my app
navigation is even derived from state: Root reacts to `currentUser` and swaps LoggedOut/LoggedIn.

**What's a viewless RIB for?**
To own a **scope or state** without a screen. `RobotSession` owns the robot's live state and the device connector and
hands its children read-only streams; `LoggedIn` coordinates "pick a device, then run a session". It also lets one RIB
place several children's views (the four tabs) into a container.

**How do RIBs communicate?**
Child → parent via a **weak listener protocol**; parent → child via the **builder arguments + DI**; siblings never talk
directly. Cross-cutting state is shared through a **read-only stream** provided by a common ancestor.

**How do you avoid memory leaks / retain cycles?**
Strong ownership goes only *down* (router → interactor/view/children). Upward references are weak. Subscriptions use
`disposeOnDeactivate(interactor:)`, so detaching a RIB cancels them. The LeakDetector catches mistakes in debug.

**How do you handle threading?**
State relays can be updated anywhere; before touching UI the interactor uses `.observe(on: MainScheduler.instance)`.
Mocks take an injected scheduler so tests use a background scheduler or manual ticks and stay deterministic.

**How do you test a RIB?**
*Interactor:* create it with a **stub presenter**, a stub/mutable stream and a spy listener/router, activate it, drive
inputs, assert on rendered view models and listener/router calls. *View-model mapping* as **pure static functions**.
*Router:* check attach/detach with mock builders. *Services/mocks:* unit-test the simulation. Plus one smoke test that
**builds the real DI graph**, and a UI test for the end-to-end flow.

**How did you hide the device so it can be swapped for hardware?**
A single `RobotConnecting` protocol; only the session RIB holds it. Feature RIBs request actions through listener
protocols and read state through a read-only stream. `DeviceManaging.connector(for:)` is the factory, so a real
BLE/Wi-Fi implementation replaces the mock in one place (`RootComponent`), with no RIB changes. Same for auth.

**How do you do deep links?**
RIBs provides **Workflows**: a sequence of steps that attaches/navigates RIBs in order and waits for each to be ready
(each step waits for the next RIB's interactor to be available). I didn't need it here; I'd model "open this device's history" as a
workflow: root → logged-in → session → select tab.

**What is a Worker?**
A lifecycle-bound unit of logic with no view (e.g. a sync job, a listener on a socket). It's started with an
interactor's lifecycle and stopped when it deactivates. In my app that role is played by interactor subscriptions.

**How do you decide what's its own RIB?**
If it has **its own business logic or scope**, a lifecycle that differs from its parent, or needs to be reused/tested
alone. `ScheduleEditor` is a RIB because it is a self-contained, modal flow with its own save/cancel result; a tiny
static subview is not.

**What are the downsides of RIBs?**
Lots of **boilerplate** per RIB (5+ files), a **learning curve**, easy to over-split, and you must be disciplined about
the rules (e.g. keeping logic out of routers/views). Mitigations: templates/code generation, clear conventions,
small RIBs only where there's real logic. For a tiny app it's overkill.

**How does DI differ from a Service Locator / singletons?**
Dependencies are **declared** (a protocol per RIB) and **provided by scoped parents**, so each unit only sees what it
asked for; they're **swappable in tests**, and Needle **verifies the graph at generation time**. A service locator hides
dependencies; singletons make scopes and tests hard.

**How does Needle's compile-time checking work?**
A generator parses the component tree and dependency protocols, matches each required property (by name and type) with
the closest ancestor that provides it, generates the provider classes, and **fails if anything is missing**. Result:
runtime "missing dependency" crashes become build-time errors.

**What would you change if the app grew?**
Split into modules per RIB group (with Needle's per-module generation), add Workflows for deep links, introduce a
shared "design system", keep one stream owner per piece of state, and add a per-RIB code template.

---

## 13. Traps & honest trade-offs (say these to sound experienced)

* **Don't put logic in routers or views.** If a router has an `if` about business state, move it to the interactor.
* **Don't share mutable state through a child.** One owner writes; others read through read-only streams.
* **Don't forget `disposeOnDeactivate`** — a plain `.disposed(by:)` bag on a long-lived object can outlive the RIB.
* **Detaching ≠ hiding.** If a view stays on screen after its RIB is detached (or the reverse), you get ghost UI or a
  dead RIB; always pair attach↔present and detach↔dismiss.
* **Subscribe in `didBecomeActive`, not in `init`.** `disposeOnDeactivate` on an inactive interactor disposes
  immediately.
* **Needle visibility quirk:** providers must be `public` (with the version used here); remember to regenerate.
* **A RIB is not a screen.** Don't create one per view controller by reflex.

## 14. 60-second recap script

> "The app is a tree of RIBs. Each has an **Interactor** with the business logic, a **Router** that attaches child RIBs,
> a **Builder** that wires everything, and a **passive view** driven by view models. Children report up through weak
> **listener** protocols; parents pass things down through the builder and **DI** — I used **Needle**, where each RIB
> declares a dependency protocol, parents provide, and a generator verifies the graph. State is exposed as
> **read-only RxSwift streams** that replay the latest value; the owner writes, everyone else observes, and
> subscriptions use `disposeOnDeactivate`, so detaching a RIB cancels everything under it. Services like auth and the
> device are behind protocols with mocks, so I can swap in real implementations without touching any RIB. It's
> verbose, but it scales with big teams and makes business logic easy to test."

---

*Where to look in this repo for each idea:* the RIB anatomy → `RibRoomba/RIBs/Home/`; viewless scope + mutable/read-only
stream → `RibRoomba/RIBs/RobotSession/`; parent-swaps-children from state → `RibRoomba/RIBs/Root/`; modal child RIB →
`RibRoomba/RIBs/Schedule/` + `ScheduleEditor/`; DI wiring → every `*Component.swift` and
`RibRoomba/Generated/NeedleGenerated.swift`; full runtime walkthrough → [SEQUENCE.md](SEQUENCE.md); formal architecture →
[ARCHITECTURE.md](ARCHITECTURE.md).
