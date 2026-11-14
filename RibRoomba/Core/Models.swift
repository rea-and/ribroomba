import Foundation

// MARK: - Live robot state

public enum RobotStatus: String, Codable, Equatable {
    case docked, charging, cleaning, paused, returningToDock, error
}

public enum CleaningMode: String, Codable, CaseIterable, Equatable {
    case quick, standard, deep

    var displayName: String {
        switch self {
        case .quick: return "Quick"
        case .standard: return "Standard"
        case .deep: return "Deep"
        }
    }

    /// Square meters covered per simulation tick.
    var areaPerTick: Double {
        switch self {
        case .quick: return 1.5
        case .standard: return 1.0
        case .deep: return 0.6
        }
    }
}

public struct RobotState: Equatable {
    var status: RobotStatus
    var batteryPercent: Int
    var binPercent: Int
    var mode: CleaningMode
    /// Area covered by the current run, in m².
    var areaCleaned: Double
    var errorMessage: String?

    static let initial = RobotState(status: .docked, batteryPercent: 100, binPercent: 10,
                                    mode: .standard, areaCleaned: 0, errorMessage: nil)
}

public enum ConnectionState: Equatable {
    case connecting, connected, disconnected
}

// MARK: - Commands

public enum RobotCommand: Equatable {
    case start(CleaningMode)
    case pause
    case resume
    case returnToDock
    case emptyBin
}

// MARK: - History

public struct CleaningRecord: Codable, Equatable {
    enum Outcome: String, Codable { case completed, interrupted }

    var id: UUID
    var startDate: Date
    var duration: TimeInterval
    var area: Double
    var mode: CleaningMode
    var outcome: Outcome
}

// MARK: - Schedule

public struct ScheduleEntry: Codable, Equatable {
    var id: UUID
    /// `Calendar` weekday: 1 = Sunday … 7 = Saturday.
    var weekday: Int
    var hour: Int
    var minute: Int
    var mode: CleaningMode
    var isEnabled: Bool

    init(id: UUID = UUID(), weekday: Int, hour: Int, minute: Int, mode: CleaningMode = .standard, isEnabled: Bool = true) {
        self.id = id
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
        self.mode = mode
        self.isEnabled = isEnabled
    }
}

// MARK: - Settings

public enum SuctionPower: String, Codable, CaseIterable, Equatable {
    case eco, balanced, max

    var displayName: String { rawValue.capitalized }
}

public struct RobotSettings: Codable, Equatable {
    var name: String
    var suction: SuctionPower
    var carpetBoost: Bool

    static let `default` = RobotSettings(name: "Rib", suction: .balanced, carpetBoost: true)
}

// MARK: - Errors

public enum RobotError: Error, LocalizedError, Equatable {
    case notConnected
    case rejected(String)

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "The robot is not connected."
        case .rejected(let reason): return reason
        }
    }
}
