import Foundation

/// Core rules engine that evaluates reminders and makes adaptive decisions
public class ReminderRulesEngine {
    private let rules: [ReminderRule]
    
    public init(rules: [ReminderRule] = []) {
        // Initialize with default rules if none provided
        self.rules = rules.isEmpty ? Self.defaultRules() : rules
    }
    
    /// Evaluates all rules and returns the most confident decision
    public func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision {
        let decisions = rules.compactMap { rule in
            rule.evaluate(reminder: reminder, history: history)
        }
        
        // Return the decision with highest confidence, or a default no-action decision
        return decisions.max(by: { $0.confidence < $1.confidence })
            ?? .noAction(because: "No applicable rules found")
    }
    
    /// Default set of rules
    private static func defaultRules() -> [ReminderRule] {
        [
            SnoozePatternRule(),
            EscalationRule(),
            TimeOfDayOptimizationRule(),
            LocationSuggestionRule()
        ]
    }
}

// MARK: - Default Rules

/// Rule that detects snooze patterns and adjusts snooze duration
private struct SnoozePatternRule: ReminderRule {
    func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision? {
        guard reminder.status == .snoozed else { return nil }
        guard history.snoozeCount > 0 else { return nil }
        
        // If snoozed multiple times recently, increase snooze duration
        if history.snoozeCount >= 3 {
            let baseDuration: TimeInterval = 15 * 60 // 15 minutes
            let multiplier = min(Double(history.snoozeCount), 8.0)
            let duration = baseDuration * multiplier
            
            let nextDate = Date().addingTimeInterval(duration)
            let minutes = Int(duration / 60)
            
            return .reschedule(
                to: nextDate,
                because: "You've snoozed this \(history.snoozeCount) times. Extending snooze to \(minutes) minutes to give you more time.",
                escalationLevel: min(history.snoozeCount / 2, 3)
            )
        }
        
        // Default snooze: 10 minutes
        let nextDate = Date().addingTimeInterval(10 * 60)
        return .reschedule(
            to: nextDate,
            because: "Standard 10-minute snooze applied."
        )
    }
}

/// Rule that escalates reminders based on interaction patterns
private struct EscalationRule: ReminderRule {
    func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision? {
        // Escalate if ignored multiple times
        if history.ignoreCount >= 2 {
            let newLevel = reminder.escalationLevel + 1
            return .escalate(
                to: newLevel,
                because: "This reminder has been ignored \(history.ignoreCount) times. Increasing priority to ensure it gets your attention."
            )
        }
        
        // Escalate if snoozed many times without completion
        if history.snoozeCount >= 5 && history.completionCount == 0 {
            let newLevel = reminder.escalationLevel + 1
            return .escalate(
                to: newLevel,
                because: "You've snoozed this \(history.snoozeCount) times without completing it. This might be important."
            )
        }
        
        return nil
    }
}

/// Rule that optimizes reminder timing based on completion patterns
private struct TimeOfDayOptimizationRule: ReminderRule {
    func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision? {
        guard let averageHour = history.averageCompletionHour else { return nil }
        guard history.completionCount >= 3 else { return nil }
        
        // If user tends to complete reminders at a specific time, suggest that time
        guard let scheduledDate = reminder.scheduledDate else { return nil }
        
        let calendar = Calendar.current
        let scheduledHour = calendar.component(.hour, from: scheduledDate)
        
        // If scheduled time differs significantly from average completion time
        if abs(scheduledHour - averageHour) >= 2 {
            var components = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
            components.hour = averageHour
            components.minute = 0
            
            if let optimizedDate = calendar.date(from: components) {
                return .suggest(
                    "You usually complete similar reminders around \(averageHour):00. Consider scheduling for that time instead.",
                    confidence: 0.75
                )
            }
        }
        
        return nil
    }
}

/// Rule that suggests location-based triggers based on patterns
private struct LocationSuggestionRule: ReminderRule {
    func evaluate(reminder: Reminder, history: ReminderHistory) -> ReminderDecision? {
        // Only suggest if reminder doesn't have location trigger
        guard reminder.locationTrigger == nil else { return nil }
        
        // If user has high completion rate, no need to suggest location
        guard history.completionRate < 0.7 else { return nil }
        
        // If snoozed frequently, suggest adding location trigger
        if history.snoozeFrequency > 2.0 {
            return .suggest(
                "You often snooze this reminder. Consider adding a location trigger (like 'Home' or 'Office') to make it more contextual.",
                confidence: 0.6
            )
        }
        
        return nil
    }
}
