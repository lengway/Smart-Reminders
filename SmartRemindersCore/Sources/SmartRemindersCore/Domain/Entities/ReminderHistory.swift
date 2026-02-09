import Foundation

/// Tracks user interaction history with a reminder for rules engine analysis
public struct ReminderHistory: Codable, Equatable {
    public let reminderId: UUID
    
    // Interaction counts
    public var snoozeCount: Int
    public var ignoreCount: Int
    public var completionCount: Int
    
    // Timing patterns
    public var snoozeTimes: [Date]
    public var completionTimes: [Date]
    public var ignoreTimes: [Date]
    
    // Execution patterns (hour of day when completed)
    public var executionHours: [Int]
    
    // Last interaction
    public var lastInteractionDate: Date?
    
    public init(
        reminderId: UUID,
        snoozeCount: Int = 0,
        ignoreCount: Int = 0,
        completionCount: Int = 0,
        snoozeTimes: [Date] = [],
        completionTimes: [Date] = [],
        ignoreTimes: [Date] = [],
        executionHours: [Int] = [],
        lastInteractionDate: Date? = nil
    ) {
        self.reminderId = reminderId
        self.snoozeCount = snoozeCount
        self.ignoreCount = ignoreCount
        self.completionCount = completionCount
        self.snoozeTimes = snoozeTimes
        self.completionTimes = completionTimes
        self.ignoreTimes = ignoreTimes
        self.executionHours = executionHours
        self.lastInteractionDate = lastInteractionDate
    }
}

// MARK: - History Updates

extension ReminderHistory {
    public mutating func recordSnooze(at date: Date = Date()) {
        snoozeCount += 1
        snoozeTimes.append(date)
        lastInteractionDate = date
    }
    
    public mutating func recordCompletion(at date: Date = Date()) {
        completionCount += 1
        completionTimes.append(date)
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        executionHours.append(hour)
        
        lastInteractionDate = date
    }
    
    public mutating func recordIgnore(at date: Date = Date()) {
        ignoreCount += 1
        ignoreTimes.append(date)
        lastInteractionDate = date
    }
}

// MARK: - Pattern Analysis

extension ReminderHistory {
    /// Average hour of day when reminders are completed
    public var averageCompletionHour: Int? {
        guard !executionHours.isEmpty else { return nil }
        let sum = executionHours.reduce(0, +)
        return sum / executionHours.count
    }
    
    /// Snooze frequency (snoozes per completion)
    public var snoozeFrequency: Double {
        guard completionCount > 0 else { return 0 }
        return Double(snoozeCount) / Double(completionCount)
    }
    
    /// Completion rate (completions / total interactions)
    public var completionRate: Double {
        let total = completionCount + ignoreCount
        guard total > 0 else { return 0 }
        return Double(completionCount) / Double(total)
    }
    
    /// Recent snooze pattern (last 3 snoozes)
    public var recentSnoozePattern: [Date] {
        Array(snoozeTimes.suffix(3))
    }
    
    /// Time between recent snoozes
    public var averageSnoozeDuration: TimeInterval? {
        let recent = recentSnoozePattern
        guard recent.count >= 2 else { return nil }
        
        var durations: [TimeInterval] = []
        for i in 1..<recent.count {
            let duration = recent[i].timeIntervalSince(recent[i-1])
            durations.append(duration)
        }
        
        return durations.reduce(0, +) / Double(durations.count)
    }
}
