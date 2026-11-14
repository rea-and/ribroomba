# RibRoomba

An iPhone companion app for a robot-vacuum ("Roomba"-type) device, built **strictly with
[RIBs](https://github.com/uber/RIBs-iOS)**, **[Needle](https://github.com/uber/needle)** for dependency injection,
**RxSwift** for reactive state and programmatic **UIKit** views.

The device, the account backend and device discovery are **mocked behind protocols**, so the whole app is usable today
without hardware, and real implementations can be dropped in later without touching any RIB.

## Features

* **Login / sign-up** with validation and a persisted session
* **Search & add robots** nearby (simulated scan and pairing); manage your list of robots
* **Home** — live status, battery, bin level; start (Quick / Standard / Deep), pause, resume, return to dock, empty bin
* **Schedule** — weekly cleaning entries (add / edit / toggle / delete); the simulated robot executes them itself
* **History** — past cleaning runs with totals, completed vs. interrupted
* **Settings** — name, suction power, carpet boost, switch device, sign out

The simulated robot behaves like firmware: it drains battery, fills its bin, returns to the dock on low battery, charges,
and stops with an error when the bin is full. Time is accelerated (1 s = 1 simulated minute) and runs only while the app
is in the foreground.

## Quick start

Requirements: Xcode with an iOS Simulator runtime, [XcodeGen](https://github.com/yonaskolb/XcodeGen) and
[Needle](https://github.com/uber/needle) (`brew install xcodegen needle`).

```sh
git clone https://github.com/rea-and/ribroomba.git
cd ribroomba
xcodegen generate            # the .xcodeproj is generated from project.yml
open RibRoomba.xcodeproj     # pick an iPhone simulator and Run
```

Log in with the demo account **`demo@ribroomba.app` / `roomba123`** (or sign up), tap **+**, wait for robots to appear,
add one, and open it.

**Signing:** the Simulator needs no development team. To run on a physical iPhone, copy
`Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your `DEVELOPMENT_TEAM` (the file is git-ignored).

## Tests

```sh
xcodebuild test -project RibRoomba.xcodeproj -scheme RibRoomba \
  -destination 'platform=iOS Simulator,name=<an installed iPhone>'
```

46 unit tests (mock robot, auth, device manager, interactors, view models, and a test that builds the real
Needle-wired RIB tree) plus one end-to-end UI test that walks the whole flow.

## Project layout

```
RibRoomba/App/         AppDelegate + SceneDelegate (registers Needle providers, launches the Root RIB)
RibRoomba/Core/        domain models, the three service protocols, and their mocks (no UIKit)
RibRoomba/RIBs/        one folder per RIB: Component, Builder, Interactor, Router, ViewController
RibRoomba/Generated/   NeedleGenerated.swift — checked in; regenerate with Scripts/generate-needle.sh
RibRoombaTests/        unit tests          RibRoombaUITests/   end-to-end UI test
```

The RIB tree: `Root` → `LoggedOut` | `LoggedIn` → `Devices` (+ `AddDevice`) | `RobotSession` → `Home`, `Schedule`
(+ `ScheduleEditor`), `History`, `Settings`.

## Swapping the mocks for real services

All outside-world access goes through `AuthServicing`, `DeviceManaging` and `RobotConnecting`. Implement them and change
the two `shared { … }` lines in `RibRoomba/RIBs/Root/RootComponent.swift`; no RIB changes.

## Working with Needle

After changing any `Component` or `Dependency` protocol, regenerate the checked-in graph:

```sh
Scripts/generate-needle.sh          # regenerate
Scripts/generate-needle.sh --check  # fail if stale (good for CI)
```

## Documentation

* [ARCHITECTURE.md](ARCHITECTURE.md) — the architecture, RIB anatomy, DI graph, service boundary, conventions
* [SEQUENCE.md](SEQUENCE.md) — step-by-step runtime walkthrough: app start, sign-up, adding a device, a cleaning run,
  History; who creates what, reactive flows, where data is stored

## Status

Verified on the iOS 27.2 simulator (iPhone 17). Not yet checked: physical devices, other screen sizes, dark mode,
accessibility. The mock auth stores passwords in `UserDefaults` in plain text — mock only, never reuse for a real
backend.
