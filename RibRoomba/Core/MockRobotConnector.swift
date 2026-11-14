import Foundation
import RxRelay
import RxSwift

/// A fully simulated robot. Time is accelerated: one tick (default 1 s) is a "minute" of robot activity.
///
/// The simulator behaves like firmware: it drains the battery while cleaning, fills the bin, returns to the dock
/// on low battery, charges while docked, stops with an error when the bin is full, and runs its own schedule.
/// Schedule and settings persist in `UserDefaults`; history is seeded on first launch.
final class MockRobotConnector: RobotConnecting {

    // Tunables (per tick).
    static let drainPerTick = 1
    static let chargePerTick = 5
    static let binFillPerTick = 2
    static let lowBatteryThreshold = 20
    static let minimumBatteryToStart = 25
    static let simulatedSecondsPerTick: TimeInterval = 60

    private let connectionRelay = BehaviorRelay<ConnectionState>(value: .disconnected)
    private let stateRelay = BehaviorRelay<RobotState>(value: .initial)
    private let historyRelay = BehaviorRelay<[CleaningRecord]>(value: [])
    private let scheduleRelay = BehaviorRelay<[ScheduleEntry]>(value: [])
    private let settingsRelay = BehaviorRelay<RobotSettings>(value: .default)

    private let defaults: UserDefaults?
    private let keys: Keys
    private let now: () -> Date
    private let connectDelay: RxTimeInterval
    private let scheduler: SchedulerType
    private let tickInterval: RxTimeInterval?
    private let tickDisposable = SerialDisposable()

    private var runStart: Date?
    private var runTicks = 0
    private var lastFiredMinute: DateComponents?

    var connection: Observable<ConnectionState> { connectionRelay.asObservable() }
    var state: Observable<RobotState> { stateRelay.asObservable() }
    var history: Observable<[CleaningRecord]> { historyRelay.asObservable() }
    var schedule: Observable<[ScheduleEntry]> { scheduleRelay.asObservable() }
    var settings: Observable<RobotSettings> { settingsRelay.asObservable() }

    /// - Parameters:
    ///   - tickInterval: Real-time length of a tick. Pass `nil` to drive the simulation manually with `tick()` (tests).
    ///   - connectDelay: Simulated pairing time.
    init(deviceID: String = "default",
         deviceName: String = RobotSettings.default.name,
         defaults: UserDefaults? = .standard,
         now: @escaping () -> Date = Date.init,
         tickInterval: RxTimeInterval? = .seconds(1),
         connectDelay: RxTimeInterval = .milliseconds(1200),
         scheduler: SchedulerType = MainScheduler.instance) {
        self.defaults = defaults
        self.keys = Keys(deviceID: deviceID)
        self.now = now
        self.tickInterval = tickInterval
        self.connectDelay = connectDelay
        self.scheduler = scheduler

        var defaultSettings = RobotSettings.default
        defaultSettings.name = deviceName
        scheduleRelay.accept(Self.load([ScheduleEntry].self, key: keys.schedule, from: defaults) ?? Self.defaultSchedule())
        settingsRelay.accept(Self.load(RobotSettings.self, key: keys.settings, from: defaults) ?? defaultSettings)
        historyRelay.accept(Self.load([CleaningRecord].self, key: keys.history, from: defaults) ?? Self.seedHistory(now: now()))
    }

    deinit { tickDisposable.dispose() }

    // MARK: - RobotConnecting

    func connect() -> Completable {
        Completable.create { [weak self] completable in
            guard let self = self else { completable(.completed); return Disposables.create() }
            if self.connectionRelay.value == .connected { completable(.completed); return Disposables.create() }
            self.connectionRelay.accept(.connecting)
            let work = Observable<Int>.timer(self.connectDelay, scheduler: self.scheduler).subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.connectionRelay.accept(.connected)
                self.startTicking()
                completable(.completed)
            })
            return work
        }
    }

    func send(_ command: RobotCommand) -> Completable {
        Completable.create { [weak self] completable in
            guard let self = self else { completable(.completed); return Disposables.create() }
            do {
                try self.apply(command)
                completable(.completed)
            } catch {
                completable(.error(error))
            }
            return Disposables.create()
        }
    }

    func updateSchedule(_ entries: [ScheduleEntry]) -> Completable {
        guardConnected { [self] in
            scheduleRelay.accept(entries)
            Self.save(entries, key: keys.schedule, to: defaults)
        }
    }

    func updateSettings(_ settings: RobotSettings) -> Completable {
        guardConnected { [self] in
            settingsRelay.accept(settings)
            Self.save(settings, key: keys.settings, to: defaults)
        }
    }

    func clearHistory() -> Completable {
        guardConnected { [self] in
            historyRelay.accept([])
            Self.save([CleaningRecord](), key: keys.history, to: defaults)
        }
    }

    // MARK: - Simulation

    /// Advances the simulation by one tick. Called by the internal timer, or directly by tests.
    func tick() {
        guard connectionRelay.value == .connected else { return }
        var s = stateRelay.value
        switch s.status {
        case .cleaning:
            runTicks += 1
            s.batteryPercent = max(0, s.batteryPercent - Self.drainPerTick)
            s.binPercent = min(100, s.binPercent + Self.binFillPerTick)
            s.areaCleaned += s.mode.areaPerTick
            if s.binPercent >= 100 {
                finishRun(&s, outcome: .interrupted)
                s.status = .error
                s.errorMessage = "Bin is full. Empty it to continue."
            } else if s.batteryPercent <= Self.lowBatteryThreshold {
                finishRun(&s, outcome: .interrupted)
                s.status = .returningToDock
            } else if s.areaCleaned >= targetArea(for: s.mode) {
                finishRun(&s, outcome: .completed)
                s.status = .returningToDock
            }
        case .returningToDock:
            // Docking takes a single tick in the simulation.
            s.status = .charging
        case .charging:
            s.batteryPercent = min(100, s.batteryPercent + Self.chargePerTick)
            if s.batteryPercent >= 100 { s.status = .docked }
        case .docked, .paused, .error:
            break
        }
        stateRelay.accept(s)
        fireScheduleIfDue()
    }

    private func startTicking() {
        guard let interval = tickInterval else { return }
        tickDisposable.disposable = Observable<Int>.interval(interval, scheduler: scheduler)
            .subscribe(onNext: { [weak self] _ in self?.tick() })
    }

    private func apply(_ command: RobotCommand) throws {
        guard connectionRelay.value == .connected else { throw RobotError.notConnected }
        var s = stateRelay.value
        switch command {
        case .start(let mode):
            try validateStart(s)
            beginRun(&s, mode: mode)
        case .pause:
            guard s.status == .cleaning else { throw RobotError.rejected("The robot is not cleaning.") }
            s.status = .paused
        case .resume:
            guard s.status == .paused else { throw RobotError.rejected("The robot is not paused.") }
            s.status = .cleaning
        case .returnToDock:
            switch s.status {
            case .cleaning, .paused:
                finishRun(&s, outcome: .interrupted)
                s.status = .returningToDock
            case .error:
                s.status = .returningToDock; s.errorMessage = nil
            default:
                throw RobotError.rejected("The robot is already docked or returning.")
            }
        case .emptyBin:
            guard s.status != .cleaning else { throw RobotError.rejected("Pause the robot before emptying the bin.") }
            s.binPercent = 0
            if s.status == .error { s.status = .docked; s.errorMessage = nil }
        }
        stateRelay.accept(s)
    }

    private func validateStart(_ s: RobotState) throws {
        switch s.status {
        case .cleaning, .paused, .returningToDock:
            throw RobotError.rejected("The robot is busy.")
        case .error:
            throw RobotError.rejected(s.errorMessage ?? "The robot needs attention.")
        case .docked, .charging:
            if s.binPercent >= 100 { throw RobotError.rejected("Bin is full. Empty it first.") }
            if s.batteryPercent < Self.minimumBatteryToStart {
                throw RobotError.rejected("Battery too low to start (\(s.batteryPercent)%). Let it charge.")
            }
        }
    }

    private func beginRun(_ s: inout RobotState, mode: CleaningMode) {
        s.status = .cleaning
        s.mode = mode
        s.areaCleaned = 0
        s.errorMessage = nil
        runStart = now()
        runTicks = 0
    }

    private func finishRun(_ s: inout RobotState, outcome: CleaningRecord.Outcome) {
        guard let start = runStart else { return }
        let record = CleaningRecord(id: UUID(), startDate: start,
                                    duration: TimeInterval(runTicks) * Self.simulatedSecondsPerTick,
                                    area: (s.areaCleaned * 10).rounded() / 10, mode: s.mode, outcome: outcome)
        let updated = [record] + historyRelay.value
        historyRelay.accept(updated)
        Self.save(updated, key: keys.history, to: defaults)
        runStart = nil
        s.areaCleaned = 0
    }

    private func targetArea(for mode: CleaningMode) -> Double {
        switch mode {
        case .quick: return 12
        case .standard: return 25
        case .deep: return 40
        }
    }

    private func fireScheduleIfDue() {
        let s = stateRelay.value
        guard s.status == .docked || s.status == .charging else { return }
        let c = Calendar.current.dateComponents([.weekday, .hour, .minute], from: now())
        guard c != lastFiredMinute else { return }
        guard let entry = scheduleRelay.value.first(where: {
            $0.isEnabled && $0.weekday == c.weekday && $0.hour == c.hour && $0.minute == c.minute
        }) else { return }
        lastFiredMinute = c
        // A scheduled run is skipped (like real firmware) if the robot can't start right now.
        try? apply(.start(entry.mode))
    }

    private func guardConnected(_ work: @escaping () -> Void) -> Completable {
        Completable.create { [weak self] completable in
            guard let self = self, self.connectionRelay.value == .connected else {
                completable(.error(RobotError.notConnected)); return Disposables.create()
            }
            work()
            completable(.completed)
            return Disposables.create()
        }
    }

    // MARK: - Persistence & seed data

    private struct Keys {
        let schedule: String, settings: String, history: String
        init(deviceID: String) {
            schedule = "mock.\(deviceID).schedule"
            settings = "mock.\(deviceID).settings"
            history = "mock.\(deviceID).history"
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults?) -> T? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String, to defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults?.set(data, forKey: key)
    }

    private static func defaultSchedule() -> [ScheduleEntry] {
        [ScheduleEntry(weekday: 2, hour: 9, minute: 0, mode: .standard),
         ScheduleEntry(weekday: 5, hour: 9, minute: 0, mode: .quick, isEnabled: false)]
    }

    private static func seedHistory(now: Date) -> [CleaningRecord] {
        let day: TimeInterval = 86_400
        return [
            CleaningRecord(id: UUID(), startDate: now - 1 * day, duration: 2_100, area: 24.5, mode: .standard, outcome: .completed),
            CleaningRecord(id: UUID(), startDate: now - 3 * day, duration: 900, area: 11.0, mode: .quick, outcome: .completed),
            CleaningRecord(id: UUID(), startDate: now - 6 * day, duration: 1_200, area: 13.2, mode: .deep, outcome: .interrupted),
        ]
    }
}
