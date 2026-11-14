# RibRoomba — Architecture

RibRoomba is an iPhone companion app for a robot-vacuum ("Roomba"-type) device. It is built **strictly with RIBs**
(Uber's Router–Interactor–Builder framework), **Needle** for dependency injection, **RxSwift/RxRelay** for reactive
state, and **UIKit** for passive views.

The app is fully usable today without hardware: login/signup, device discovery/pairing and the robot itself are all
**mocked behind protocols** (`AuthServicing`, `DeviceManaging`, `RobotConnecting`). No RIB knows or cares that they
are mocks; replacing them with real implementations is a change in one file (`RootComponent.swift`).

> **A note on the guidelines.** The brief asked to follow a Google Doc ("iOS RIBs Architecture Overview: UIKit,
> Needle DI, and RxSwift"). That document is private and could not be read when this project was written (only its
> title was visible). The architecture below follows the doc's title/stack and standard RIBs conventions. Please
> diff this file against the doc and adjust anything that deviates.

> **Companion document:** [SEQUENCE.md](SEQUENCE.md) walks through the app step by step (start-up, sign-up, adding a
> device, showing it, a cleaning run, History) — who creates which object, the listener calls, the reactive flows
> and where data is stored. This file is the static view; that one is the runtime view.

---

## 1. Stack

| Concern | Choice | Version |
|---|---|---|
| Architecture | [RIBs-iOS](https://github.com/uber/RIBs-iOS) | 0.16.3 (SPM, exact) |
| Dependency injection | [Needle](https://github.com/uber/needle) `NeedleFoundation` + generator | 0.25.1 |
| Reactive | RxSwift / RxRelay | 6.9.0 |
| UI | UIKit, programmatic (no storyboards/xibs) | iOS 16+ |
| Project generation | XcodeGen (`project.yml`) | — |
| Tests | XCTest, RxBlocking, XCUITest | — |

## 2. The RIB tree

The RIB tree — not the view hierarchy — is the source of truth for app state. Each box is a RIB; **(v)** = owns a
view, **(–)** = viewless (business logic only).

```
Root (v)                              hosts one full-screen content at a time
├── LoggedOut (v)                     login / sign-up form
└── LoggedIn (–)                      authenticated scope; coordinates device choice
    ├── Devices (v)                   "My robots" list, sign out
    │   └── AddDevice (v, modal)      search nearby robots + pair
    └── RobotSession (–)              owns the live robot state for ONE device
        ├── Home (v)                  status, battery, bin, start/pause/dock
        ├── Schedule (v)              weekly cleaning schedule
        │   └── ScheduleEditor (v, modal)
        ├── History (v)               past cleaning runs
        └── Settings (v)              name, suction, carpet boost, switch device, sign out
```

Only one of `LoggedOut` / `LoggedIn` exists at a time, and only one of `Devices` / `RobotSession` under `LoggedIn`.
Detaching a RIB deactivates its whole subtree, which cancels every Rx subscription inside it.

### Navigation is a consequence of state

```
launch ─► Root observes AuthServicing.currentUser
            nil  ─► attach LoggedOut           user ─► attach LoggedIn ─► attach Devices
LoggedOut: signIn/signUp ─► service publishes user ─► Root reacts   (LoggedOut never navigates itself)
Devices: select device ─► LoggedIn detaches Devices, attaches RobotSession(device)
Settings: "Switch device" ─► Session ─► LoggedIn ─► detach Session, attach Devices
Settings/Devices: "Sign out" ─► … ─► Root ─► AuthServicing.signOut() ─► currentUser = nil ─► attach LoggedOut
```

Because Root derives its child from `currentUser`, a restored session at launch, a fresh login, and a sign-out all
take the same code path.

## 3. Anatomy of a RIB

Every RIB lives in `RibRoomba/RIBs/<Name>/` with the same files:

| File | Role | Imports |
|---|---|---|
| `<Name>Component.swift` | Needle `Component` + its `Dependency` protocol: what the RIB needs, what it offers children | `NeedleFoundation` only |
| `<Name>Builder.swift` | `Buildable` protocol + `Builder`; the **only** place a RIB's constituents are instantiated; declares the `Listener` protocol | `RIBs` only |
| `<Name>Interactor.swift` | All business logic. Declares `Routing`, `Presentable`, `PresentableListener`, `Interactable` protocols and the view-model struct | `RIBs`, `RxSwift` |
| `<Name>Router.swift` | Attaches/detaches children, arranges presentation. No business logic | `RIBs` |
| `<Name>ViewController.swift` | **Passive** UIKit view: renders a view model, forwards user input to its listener. No decisions | `RIBs`, `UIKit` |

Viewless RIBs (`LoggedIn`, `RobotSession`) have no view controller; their router places children's views into a
`ContentHosting` object the parent lends them (implemented by `RootViewController`).

### Rules of the road

1. **Interactor decides, router arranges, view renders.** The interactor turns streams into *view models* (plain
   structs). Views never see domain models, services or streams.
2. **Child → parent communication is only through the child's weak `Listener` protocol** (e.g. `HomeListener`,
   `DevicesListener`). Children never reference parents or siblings. The parent's interactor conforms to the child
   listener protocols and decides what happens.
3. **Parent → child is only through the builder's `build(...)` arguments** (listener, plus runtime values such as
   `Device` or `User`) and Needle dependencies.
4. **No RIB talks to the device or backend directly** unless it owns that boundary (§5).
5. **Rx subscriptions in interactors end with `.disposeOnDeactivate(interactor: self)`**, and are made in
   `didBecomeActive()`. There are no `DisposeBag`s in interactors; the RIB lifecycle is the single owner.
6. Anything delivered to a view is `.observe(on: MainScheduler.instance)` first.
7. Modal flows (`ScheduleEditor`, `AddDevice`) are `isModalInPresentation = true`, so only the RIB's own Save/Cancel
   can close them — the RIB can never be left attached with no view (or vice versa).

## 4. Dependency injection (Needle)

```
RootComponent (BootstrapComponent)          provides: authService, deviceManager
├── LoggedOutComponent    needs authService
└── LoggedInComponent     needs deviceManager
    ├── DevicesComponent       needs deviceManager
    │   └── AddDeviceComponent needs deviceManager
    └── SessionComponent       needs deviceManager;  provides: robotStateStream (read-only)
        ├── HomeComponent         needs robotStateStream
        ├── ScheduleComponent     needs robotStateStream
        │   └── ScheduleEditorComponent   (no dependencies)
        ├── HistoryComponent      needs robotStateStream
        └── SettingsComponent     needs robotStateStream
```

The same graph as a hierarchy of *which component creates which*: a parent component creates the child component
(`XComponent(parent: self)`) and wraps it in the child's builder; the builder creates the RIB's objects. Details of
the creation order are in [SEQUENCE.md](SEQUENCE.md).

* Each RIB declares a `…Dependency` protocol listing exactly what it reads. Needle generates the providers and
  statically verifies the whole graph; a missing dependency fails **generation**, not runtime.
* **Generated code is checked in**: `RibRoomba/Generated/NeedleGenerated.swift`. Regenerate after *any* change to a
  `Component` or `Dependency` protocol:
  ```sh
  Scripts/generate-needle.sh          # regenerate
  Scripts/generate-needle.sh --check  # fails if the checked-in file is stale (use in CI)
  ```
  `AppDelegate` calls `registerProviderFactories()` once at launch; `SceneDelegate` then builds the tree.
* **Mutable vs read-only state.** `SessionComponent` owns a `MutableRobotStateStream` (shared) but exposes only
  `robotStateStream: RobotStateStreaming` (read-only `Observable`s) to children. Only `SessionInteractor` can write.
* `LoggedInComponent.sessionBuilder` is deliberately a computed property: each access creates a fresh
  `SessionComponent`, so each device session gets its own state stream.

### Two gotchas worth knowing

1. **Needle 0.25 only sees `public` provider properties.** A property that satisfies a child's dependency must be
   declared `public var`, otherwise generation reports "Could not find a provider". Because such a property's type
   must be at least as visible, the types crossing these boundaries (`RobotStateStreaming`, `AuthServicing`,
   `DeviceManaging`, `RobotConnecting` and the model structs) are `public`. Properties that are *not* providers
   (child builders) stay internal.
2. **Name clash:** RIBs defines its own `Component`/`Dependency`, as does NeedleFoundation. To keep both, **no file
   imports both frameworks**: `…Component.swift` imports only `NeedleFoundation`; builders/interactors/routers import
   only `RIBs`. Preserve this when adding code.

## 5. The service boundary (mocks today, real tomorrow)

Three protocols in `RibRoomba/Core/` form the entire "outside world" surface:

| Protocol | Responsibility | Held by | Mock |
|---|---|---|---|
| `AuthServicing` | `currentUser`, `signIn`, `signUp`, `signOut` | Root (provider), `LoggedOut`, `Root` interactors | `MockAuthService` |
| `DeviceManaging` | `pairedDevices`, `scan()`, `add`, `remove`, **`connector(for:)`** | `Devices`, `AddDevice`, `RobotSession` | `MockDeviceManager` |
| `RobotConnecting` | per-device live link: state, history, schedule, settings, commands | **`RobotSession` only** | `MockRobotConnector` |

* **`RobotConnecting` never reaches feature RIBs.** `SessionInteractor` is the only consumer: it mirrors the
  connector's streams into the session's `MutableRobotStateStream`, and executes the commands children request via
  their listener protocols (`homeDidRequest(.start(.deep))`, `scheduleDidChange(_:)`, …). Failed commands become
  messages on `RobotStateStreaming.errors`, which Home shows.
* `DeviceManaging.connector(for:)` is the factory that links *which device* to *how to talk to it*, so supporting
  real hardware means implementing `DeviceManaging` (BLE/Wi-Fi/cloud) and returning real connectors.
* **To go real:** implement the protocols and change the two `shared { … }` lines in `RootComponent.swift`
  (`authService`, `deviceManager`). No RIB, builder, listener or view changes.

### What the mocks simulate

* **Auth** — in-memory + `UserDefaults` accounts, seeded demo user `demo@ribroomba.app` / `roomba123`;
  validation (email format, ≥6-char password, duplicate email, name required); 0.7 s latency; session restored on
  next launch. (Passwords are stored in plain text — *mock only*.)
* **Devices** — `scan()` reveals four nearby robots one by one (~1 s apart) then completes; pairing takes 1.5 s;
  paired devices persist and are excluded from later scans.
* **Robot** — behaves like firmware, with accelerated time (1 s = 1 simulated minute):
  cleaning drains 1 % battery and fills 2 % bin per tick; modes differ in speed and target area; auto-returns to the
  dock at ≤ 20 % battery; charges while docked; stops with an error when the bin is full until it's emptied;
  rejects invalid commands (e.g. start while busy, battery < 25 %); records every run in history; **executes its own
  schedule** (enabled entry on matching weekday/time while docked). Schedule/settings/history persist per device.
  It runs only while the app is in the foreground — it is a simulation, not a background service.

## 6. Reactive conventions

* State is exposed as `Observable` that **replays the latest value** (`BehaviorRelay.asObservable()` underneath).
  Relays (`BehaviorRelay`/`PublishRelay`) are private to their owner; consumers only get `Observable`.
* Commands are `Completable`; lookups/auth/pairing are `Single`. The Rx *scheduler is injected* into every mock
  (`MainScheduler` in the app, a background scheduler in tests), and `MockRobotConnector(tickInterval: nil)` lets
  tests advance simulated time by calling `tick()`, so tests are deterministic.
* Errors cross the boundary as typed `Error`s (`RobotError`, `AuthError`, `DeviceError`) whose
  `localizedDescription` is user-presentable.

## 7. Repository layout

```
project.yml                  XcodeGen spec (RibRoomba.xcodeproj is generated from it; commit both)
Config/Base.xcconfig         shared build settings; includes the optional, git-ignored Config/Local.xcconfig
Scripts/generate-needle.sh   regenerate / verify the Needle graph
ARCHITECTURE.md / SEQUENCE.md   static structure / runtime walkthrough
RibRoomba/
  App/AppDelegate.swift      registers Needle providers, vends the scene configuration
  App/SceneDelegate.swift    builds Root per window scene and launches it (UIScene lifecycle is mandatory on iOS 27 SDK)
  Core/                      models + the three service protocols + mocks (no UIKit)
  RIBs/<Name>/               one folder per RIB (see §3)
  Generated/                 NeedleGenerated.swift (checked in, do not edit)
RibRoombaTests/
  Core/                      service/mocks tests — pure Swift
  RIBs/                      interactor/view-model tests + a Needle-graph smoke test
RibRoombaUITests/            end-to-end UI flow
```

## 8. Testing

* `RibRoombaTests/Core` — 25 tests (of the 46 unit tests) for the mock robot (drain, bin-full error, low-battery docking, charging,
  schedule execution, persistence), auth and device manager. These files don't import UIKit/RIBs.
* `RibRoombaTests/RIBs` — interactor tests with stub presenters/listeners/routers (LoggedOut, Schedule), pure
  view-model mapping tests (Home, History, Schedule), and `AppGraphTests`, which builds the real Needle-wired tree
  and fails if a provider is missing or `NeedleGenerated.swift` is stale.
* Strategy for new RIBs: test the interactor against a stub presenter + stub `RobotStateStreaming`/service; keep
  view models as pure static functions where possible.
* `RibRoombaUITests` — one end-to-end XCUITest of the mocked app: failed login, login, search + add a robot,
  open it, start cleaning, visit Schedule/editor/History/Settings, sign out (writes screenshots to
  `/tmp/rr-shots/`).

Run everything (unit + UI): `xcodebuild test -project RibRoomba.xcodeproj -scheme RibRoomba -destination 'id=<simulator-udid>'`.

**Verification status:** on the iOS 27.2 simulator (iPhone 17) all 46 unit tests and the UI flow pass, and the app
was launched and inspected. Not checked: physical devices, other screen sizes, dark mode, accessibility, rotation.

## 9. Build & run

```sh
brew install xcodegen needle
xcodegen generate                     # only when project.yml or the file layout changes
open RibRoomba.xcodeproj              # choose an iPhone simulator, Run
# CLI:
xcodebuild test -project RibRoomba.xcodeproj -scheme RibRoomba -destination 'platform=iOS Simulator,name=<iPhone>'
```

**Signing:** the Simulator needs no development team (signing is disabled for simulator SDKs in `project.yml`). To run
on a physical iPhone, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM`;
the file is git-ignored and survives `xcodegen generate` (a team picked in Xcode's UI would be overwritten).

Log in with `demo@ribroomba.app` / `roomba123` (or sign up), tap **+**, wait for robots to appear, add one, open it.

## 10. Adding a new RIB — checklist

1. Create `RIBs/<Name>/` with Component, Builder, Interactor, Router (+ ViewController if it has UI), following §3.
2. Declare `<Name>Dependency` with only what it reads; add it as a child in its parent component
   (`var <name>Builder: <Name>Buildable { return <Name>Builder(dependency: <Name>Component(parent: self)) }`).
3. Declare `<Name>Listener`; make the parent's `…Interactable` inherit it and implement it in the parent interactor.
4. If it needs something a parent *provides*, mark that provider `public var` (§4).
5. `Scripts/generate-needle.sh`, build, add interactor tests.
6. If the RIB changes a user journey, update [SEQUENCE.md](SEQUENCE.md).

## 11. Known limitations / non-goals

* Background execution, push notifications and a real device/backend are out of scope; the simulation only runs
  while the app is foregrounded.
* iPhone only; colors are system colors (light/dark capable) but this was not visually checked; no accessibility audit or localization yet.
* The mock auth stores passwords in `UserDefaults` in plain text. Never reuse this for a real backend.
* The UIScene lifecycle is required (iOS 27 SDK): window creation lives in `SceneDelegate`, not `AppDelegate`.
* Device list is per installation, not per account (the mock `DeviceManaging` ignores the signed-in user).
