import RxSwift

/// The single abstraction over the physical device.
///
/// Only the robot-session scope holds a `RobotConnecting`; feature RIBs never see it. A real Bluetooth/Wi-Fi
/// connector replaces `MockRobotConnector` by changing one line in `RootComponent`.
///
/// All state observables replay their latest value on subscription.
public protocol RobotConnecting: AnyObject {
    var connection: Observable<ConnectionState> { get }
    var state: Observable<RobotState> { get }
    var history: Observable<[CleaningRecord]> { get }
    var schedule: Observable<[ScheduleEntry]> { get }
    var settings: Observable<RobotSettings> { get }

    func connect() -> Completable
    func send(_ command: RobotCommand) -> Completable
    func updateSchedule(_ entries: [ScheduleEntry]) -> Completable
    func updateSettings(_ settings: RobotSettings) -> Completable
    func clearHistory() -> Completable
}
