import Foundation

/// Simple interface for suggesting better schedule based on history
public protocol PersonalizationService {
    func suggestSchedule(reminder: Reminder, history: ReminderHistory) -> ReminderDecision?
}

/// Heuristic implementation using average completion hour
public struct HeuristicPersonalizationService: PersonalizationService {
    public init() {}
    
    public func suggestSchedule(reminder: Reminder, history: ReminderHistory) -> ReminderDecision? {
        guard let avgHour = history.averageCompletionHour else { return nil }
        guard let scheduledDate = reminder.scheduledDate else { return nil }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
        components.hour = avgHour
        components.minute = 0
        guard let suggested = calendar.date(from: components) else { return nil }
        if abs((calendar.component(.hour, from: scheduledDate)) - avgHour) < 2 { return nil }
        return .suggest("Лучшее время по привычкам: \(avgHour):00", confidence: 0.7)
    }
}
