import Foundation
import RxBlocking
import RxSwift

/// Runs real timers on a background queue so tests can block on them with RxBlocking.
let testScheduler: SchedulerType = ConcurrentDispatchQueueScheduler(qos: .userInitiated)

func complete(_ completable: Completable) throws {
    _ = try completable.asObservable().toBlocking(timeout: 5).toArray()
}

func latest<T>(_ observable: Observable<T>) throws -> T {
    try observable.toBlocking(timeout: 5).first()!
}

/// A date that falls exactly on the given weekday (1 = Sunday) at hour:minute, in the future.
func nextDate(weekday: Int, hour: Int, minute: Int) -> Date {
    Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: hour, minute: minute, weekday: weekday),
                              matchingPolicy: .nextTime)!
}
