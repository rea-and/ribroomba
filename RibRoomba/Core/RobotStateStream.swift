import RxRelay
import RxSwift

/// Read-only view of the robot, handed to every feature RIB through Needle.
public protocol RobotStateStreaming: AnyObject {
    var connection: Observable<ConnectionState> { get }
    var state: Observable<RobotState> { get }
    var history: Observable<[CleaningRecord]> { get }
    var schedule: Observable<[ScheduleEntry]> { get }
    var settings: Observable<RobotSettings> { get }
    /// Transient, user-presentable errors (failed commands). Does not replay.
    var errors: Observable<String> { get }
}

/// Mutable counterpart, owned by the robot-session scope. Only `SessionInteractor` writes to it.
final class MutableRobotStateStream: RobotStateStreaming {
    private let connectionRelay = BehaviorRelay<ConnectionState>(value: .connecting)
    private let stateRelay = BehaviorRelay<RobotState>(value: .initial)
    private let historyRelay = BehaviorRelay<[CleaningRecord]>(value: [])
    private let scheduleRelay = BehaviorRelay<[ScheduleEntry]>(value: [])
    private let settingsRelay = BehaviorRelay<RobotSettings>(value: .default)
    private let errorRelay = PublishRelay<String>()

    var connection: Observable<ConnectionState> { connectionRelay.asObservable() }
    var state: Observable<RobotState> { stateRelay.asObservable() }
    var history: Observable<[CleaningRecord]> { historyRelay.asObservable() }
    var schedule: Observable<[ScheduleEntry]> { scheduleRelay.asObservable() }
    var settings: Observable<RobotSettings> { settingsRelay.asObservable() }
    var errors: Observable<String> { errorRelay.asObservable() }

    func update(connection: ConnectionState) { connectionRelay.accept(connection) }
    func update(state: RobotState) { stateRelay.accept(state) }
    func update(history: [CleaningRecord]) { historyRelay.accept(history) }
    func update(schedule: [ScheduleEntry]) { scheduleRelay.accept(schedule) }
    func update(settings: RobotSettings) { settingsRelay.accept(settings) }
    func report(error: String) { errorRelay.accept(error) }
}
